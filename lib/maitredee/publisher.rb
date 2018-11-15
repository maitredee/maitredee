module Maitredee
  module Publisher
    extend ActiveSupport::Concern

    module ClassMethods
      def call(*args)
        publisher = new(*args)
        publisher.compose
        publisher.published_messages
      end

      def publish_defaults(topic: nil, event_name: nil, validation_schema: nil)
        @publish_defaults = {
          topic: topic,
          event_name: event_name,
          validation_schema: validation_schema
        }
      end

      def get_publish_defaults
        @publish_defaults
      end
    end

    def published_messages
      @published_messages ||= []
    end

    def publish(topic: nil, event_name: nil, validation_schema: nil, primary_key: nil, body:)
      defaults = self.class.get_publish_defaults
      published_messages << Maitredee.publish(
        topic: topic || defaults[:topic],
        event_name: event_name || defaults[:event_name],
        validation_schema: validation_schema || defaults[:validation_schema],
        primary_key: primary_key,
        body: body
      )
    end
  end
end
