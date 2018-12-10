module Maitredee
  class Publisher
    class << self
      def call(*args)
        publisher = new(*args)
        publisher.process
        publisher.published_messages
      end

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

    def published_messages
      @published_messages ||= []
    end

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
