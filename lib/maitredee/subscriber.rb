require "shoryuken"

module Maitredee
  ##
  # Inherit from this class to easily subscrive to messages:
  #
  #   class RecipeSubscriber < Maitredee::Subscriber
  #     subscribe_to :recipes do
  #       event(:update) # by default this calls the event_name, #delete
  #     end
  #
  #     def update
  #       # do some work
  #     end
  #   end
  #
  # If you want to process a message manually
  #
  #   RecipePublisher.process()
  #
  # Note that `call` is a class method, `process` is an instance method.
  class Subscriber
    EventConfig = Struct.new(
      :action,
      :event_name,
      keyword_init: true
    )

    class SubscriberProxy
      attr_reader :subscriber

      def initialize(subscriber)
        @subscriber = subscriber
      end

      # configure subscriber to listen to event_name
      # @param event_name [nil, #to_s]
      # @param to [#to_s] must be valid method name
      def event(event_name, to: nil)
        if event_name.nil? && to.nil?
          raise ArgumentError, "event_name and to: cannot both be nil"
        end

        event_config = EventConfig.new(
          event_name: event_name.to_s,
          action: (to || event_name).to_s
        )

        subscriber.event_configs[event_config.event_name] = event_config
      end

      # configure a default method to be called if not specifically configured to be listened to
      # @param event_name [#to_s]
      # @param to [#to_sym] must be valid method name
      def default_event(to:)
        subscriber.event_configs.default = EventConfig.new(
          event_name: nil,
          action: to.to_s
        )
      end
    end

    class << self
      attr_reader :topic_name

      # configures Subscriber to which topic it should listen to and lets you configure events in the block
      # @example subscribe to a topic
      #   class RecipeSubscriber < Maitredee::Subscriber
      #     subscribe_to :recipes do
      #       event(:delete) # by default this calls the event_name, #delete
      #       event(:update, to: :process) # events can be routed to different methods though
      #       event(nil, to: :process) # subscribe without event names
      #
      #       default_event(to: :process) # this will default a catch all route
      #     end
      #
      #     def delete
      #       # do some work
      #     end
      #
      #     def process
      #       # do some work
      #     end
      #   end
      #
      # @see SubscriberProxy
      # @param topic_name [#to_s]
      # @param queue_name [#to_s] overide default generation from class name
      # @param queue_resource_name [#to_s] overide default generation from queue_name and topic_name
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

      # @api private
      def event_configs
        @event_configs ||= {}
      end

      # returns the queue_name set in .subscribe_to or is generated off the class name without `Subscriber`
      def queue_name
        @queue_name ||= name.chomp(Subscriber.name.demodulize).underscore.dasherize
      end

      # Returns the resource name of the queue depending on the adapter
      # @return [String]
      def queue_resource_name
        @queue_resource_name ||= Maitredee.queue_resource_name(topic_name, queue_name)
      end

      # takes message and routes it based off SubscriberMessage#event_name
      # @param message [SubscriberMessage]
      def process(message)
        event_config = event_configs[message.event_name.to_s]
        if event_config
          new(message).send(event_config.action)
        end
      end
    end

    # @return [SubscriberMessage]
    attr_reader :message

    # @param message [SubscriberMessage]
    def initialize(message)
      @message = message
    end
  end
end
