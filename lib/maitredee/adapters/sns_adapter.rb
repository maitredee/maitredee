module Maitredee
  module Adapters
    class SnsAdapter
      def publish(message)
        client.publish(
          topic_arn: topics[message.topic_resource_name].topic_arn,
          message: message.body.to_json,
          message_attributes: {
            "topic_name" => { data_type: "String", string_value: message.topic },
            "event_name" => { data_type: "String", string_value: message.event_name },
            "primary_key" => { data_type: "String", string_value: message.primary_key },
            "schema_name" => { data_type: "String", string_value: message.validation_schema }
          }
        )
      end

      private

      def client
        @client ||= Aws::Sns::Client.new
      end

      def topics
        @topics ||= Hash.new do |hash, key|
          hash[key] = client.create_topic(
            name: topic_name(key)
          )
        end
      end
    end
  end
end
