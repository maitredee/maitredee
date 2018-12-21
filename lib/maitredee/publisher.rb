module Maitredee
  ##
  # Inherit from this class to easily publish messages:
  #
  #   class RecipePublisher < Maitredee::Publisher
  #
  #     def initialize(recipe)
  #       @recipe = recipe
  #     end
  #
  #     def process
  #       # do some work
  #     end
  #   end
  #
  # Then in your Rails app, you can do this:
  #
  #   RecipePublisher.call(1, 2, 3)
  #
  # Note that `call` is a class method, `process` is an instance method.
  class Publisher
    class << self
      # @api private
      def inherited(subclass)
        subclass.const_set("PublisherJob", Class.new(PublisherJob))
        subclass::PublisherJob.service_class = subclass
      end

      # if ActiveJob is configured this will call the publisher asyncronously
      # @param args [] arguments are passed to #call
      def call_later(*args)
        self::PublisherJob.perform_later(*args)
      end

      # call #process and return publishes messages
      # @param args [] arguments passed to #initialize
      def call(*args)
        publisher = new(*args)
        publisher.process
        publisher.published_messages
      end

      # set publish defaults
      # @param topic_name [#to_s, nil]
      # @param event_name [#to_s, nil]
      # @param schema_name [#to_s, nil]
      def publish_defaults(topic_name: nil, event_name: nil, schema_name: nil)
        @publish_defaults = {
          topic_name: topic_name,
          event_name: event_name,
          schema_name: schema_name
        }
      end

      def get_publish_defaults
        @publish_defaults
      end
    end

    # array of messages published in this instance
    # @return [Array<PublisherMessage>]
    def published_messages
      @published_messages ||= []
    end

    # publish a message with defaults
    # @param topic_name [#to_s, nil]
    # @param event_name [#to_s, nil]
    # @param schema_name [#to_s, nil]
    # @param primary_key [#to_s, nil]
    # @param body [#to_json]
    def publish(topic_name: nil, event_name: nil, schema_name: nil, primary_key: nil, body:)
      defaults = self.class.get_publish_defaults
      published_messages << Maitredee.publish(
        topic_name: topic_name || defaults[:topic_name],
        event_name: event_name || defaults[:event_name],
        schema_name: schema_name || defaults[:schema_name],
        primary_key: primary_key,
        body: body
      )
    end
  end
end
