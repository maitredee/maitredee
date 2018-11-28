require "shoryuken"

module Maitredee
  class Subscriber
    EventConfig = Struct.new(
      :action,
      :event_name,
      :minimum_schema,
      keyword_init: true
    )

    class SubscriberProxy
      attr_reader :subscriber

      def initialize(subscriber)
        @subscriber = subscriber
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

        subscriber.event_configs[event_config.event_name] = event_config
      end

      def default_event(to:, minimum_schema: nil)
        subscriber.event_configs.default = EventConfig.new(
          event_name: nil,
          action: to.to_s,
          minimum_schema: minimum_schema
        )
      end
    end

    class << self
      attr_reader :topic_name

      def subscribe_to(topic_name, queue_name: nil, queue_resource_name: nil, &block)
        @topic_name = topic_name
        @queue_name = queue_name if queue_name
        @queue_resource_name = queue_resource_name if queue_resource_name

        proxy = SubscriberProxy.new(self)
        proxy.instance_eval(&block)

        if event_configs.empty? && event_configs.default.nil?
          raise Maitredee::NoRoutesError, "No events routed"
        end

        Maitredee.register_subscriber(self)
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

      def process(message)
        event_config = event_configs[message.event_name.to_s]
        if event_config
          new(message).send(event_config.action)
        end
      end
    end

    attr_reader :message

    def initialize(message)
      @message = message
    end
  end
end
