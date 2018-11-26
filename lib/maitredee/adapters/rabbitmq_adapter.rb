require "hutch"

module Maitredee
  module Adapters
    class RabbitmqAdapter
      def publish(message)
        client.publish(
          "#{message.topic_resource_name}.#{message.event_name}",
          {
            topic_name: message.topic,
            event_name: message.event_name,
            primary_key: message.primary_key,
            schema_name: message.validation_schema,
            body: message.body,
            maitredee_version: Maitredee::VERSION
          }
        )
      end

      def client
        @hutch ||=
          begin
            Hutch.connect
            Hutch
          end
      end
      # def configure_broker(config)
      #   config.each do |topic_resource_name, queue_resource_names|
      #     queue_resource_names.each do |queue_resource_name|
      #       subscribe(
      #         topic_resource_name: topic_resource_name,
      #         queue_resource_name: queue_resource_name
      #       )
      #     end
      #   end
      # end
    end
  end
end
