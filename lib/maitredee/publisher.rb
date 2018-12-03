module Maitredee
  class Publisher
    class << self
      # call #process and return publishes messages
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

    # array of messages published in this call
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
