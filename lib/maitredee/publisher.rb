require "active_job"

module Maitredee
  class Publisher
    class << self
      attr_accessor :publisher_job

      def inherited(subclass)
        subclass.publisher_job = Class.new(PublisherJob)
        subclass.publisher_job.service_class = subclass
      end

      def call_later(*args)
        publisher_job.perform_later(*args)
      end

      def call(*args)
        publisher = new(*args)
        publisher.process
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

    class PublisherJob < ::ActiveJob::Base
      class << self
        attr_accessor :service_class

        def name
          return super if service_class.nil?

          "#{service_class}.publisher_job"
        end

        def inspect
          name
        end
      end

      def perform(*args)
        self.class.service_class.call(*args)
      end
    end
  end
end
