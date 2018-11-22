require "shoryuken"

module Maitredee
  class Subscriber
    EventConfig = Struct.new(
      :action,
      :event_name,
      :minimum_schema,
      keyword_init: true
    )

    class Worker
      include Shoryuken::Worker

      class << self
        attr_accessor :subscriber_class
      end

      def perform(sqs_message, body)
        self.class.subscriber_class.process(sqs_message, body)
      end
    end

    class SubscribeProxy
      attr_reader :controller

      def initialize(controller)
        @controller = controller
      end

      def event(event_name, to: nil, minimum_schema: nil)
        if event_name.nil? && to.nil?
          raise ArgumentError, "event_name and to: cannot both be nil"
        end

        event_config = EventConfig.new(
          event_name: event_name.to_s,
          action: (to || event_name).to_s,
          minimum_schema: minimum_schema
        )

        controller.event_configs[event_config.event_name] = event_config
      end

      def default_event(to:, minimum_schema: nil)
        controller.event_configs.default = EventConfig.new(
          event_name: nil,
          action: to.to_s,
          minimum_schema: minimum_schema
        )
      end

      def shoryuken_options(auto_delete: nil, batch: nil, body_parser: nil, auto_visibility_timeout: nil, retry_intervals: nil)
        get_shoryuken_options.merge!(
          {
            auto_delete: auto_delete,
            batch: batch,
            body_parser: body_parser,
            auto_visibility_timeout: auto_visibility_timeout,
            retry_intervals: retry_intervals
          }.compact
        )
      end

      def get_shoryuken_options
        @shoryuken_options ||= Maitredee.default_shoryuken_options.merge(
          queue: controller.queue_resource_name
        )
      end
    end

    class << self
      attr_reader :topic_name

      def subscribe_to(topic_name, queue_name: nil, queue_resource_name: nil, &block)
        @topic_name = topic_name
        @queue_name = queue_name if queue_name
        @queue_resource_name = queue_resource_name if queue_resource_name

        proxy = SubscribeProxy.new(self)
        proxy.instance_eval(&block)

        if event_configs.empty? && event_configs.default.nil?
          raise Maitredee::NoRoutesError, "No events routed"
        end

        worker_class = Class.new(Worker)
        worker_class.shoryuken_options proxy.shoryuken_options
        worker_class.subscriber_class = self
        const_set "#{name}Worker", worker_class

        Maitredee.subscriber_registry.add(self)
      end

      def event_configs
        @event_configs ||= {}
      end

      def queue_name
        @queue_name ||= name.chomp(Subscriber.name.demodulize).underscore.dasherize
      end

      def queue_resource_name
        @queue_resource_name ||= Maitredee.queue_resource_name(topic_name, queue_name)
      end

      def process(sqs_message, body)
        event_name = sqs_message.message_attributes["event_name"]&.string_value
        event_config = event_configs[event_name.to_s]
        if event_config
          new(sqs_message, body).send(event_config.action)
        end
      end
    end

    attr_reader :message, :body, :received_at

    def initialize(sqs_message, body)
      @message = sqs_message
      @body = body
      @received_at = Time.now
    end
  end
end
