require "aws-sdk-sns"
require "aws-sdk-sqs"

module Maitredee
  module Adapters
    class SnsSqsAdapter
      def publish(message)
        sns_client.publish(
          topic_arn: topics[message.topic_resource_name].arn,
          message: message.body.to_json,
          message_attributes: sns_message_attributes(
            topic_name: message.topic,
            event_name: message.event_name,
            primary_key: message.primary_key,
            schema_name: message.validation_schema
          )
        )
      end

      def configure_broker(config)
        config.each do |topic_resource_name, queue_resource_names|
          queue_resource_names.each do |queue_resource_name|
            subscribe(
              topic_resource_name: topic_resource_name,
              queue_resource_name: queue_resource_name
            )
          end
        end
      end

      def topics
        @topics ||= Hash.new do |hash, key|
          topic = sns_client.create_topic(
            name: key
          )
          hash[key] = Aws::SNS::Topic.new(topic.topic_arn)
        end
      end

      def queues
        @queues ||= Hash.new do |hash, key|
          queue_url = sqs_client.create_queue(queue_name: key).queue_url
          hash[key] = Aws::SQS::Queue.new(queue_url)
        end
      end

      def subscribe(queue_resource_name:, topic_resource_name:)
        topic = topics[topic_resource_name]
        queue = queues[queue_resource_name]
        queue_arn = queue.attributes["QueueArn"]

        sns_client.subscribe(
          topic_arn: topic.arn,
          protocol: "sqs",
          endpoint: queue_arn,
          attributes: { "RawMessageDelivery" => "true" }
        )

        queue.set_attributes(
          attributes: {
            "Policy" => sqs_policy(
              queue_arn: queue_arn,
              topic_arn: topic.arn
            )
          }
        )
      end

      private

      def sns_client
        @sns_client ||= Aws::SNS::Client.new
      end

      def sqs_client
        @sqs_client ||= Aws::SQS::Client.new
      end

      def sns_message_attributes(hash)
        hash.each_with_object({}) do |(key, val), new_hash|
          if val.present?
            new_hash[key.to_s] = {
              data_type: "String",
              string_value: val.to_s
            }
          end
        end
      end

      def sqs_policy(queue_arn:, topic_arn:)
        <<~POLICY
          {
            "Version": "2008-10-17",
            "Id": "#{queue_arn}/SQSDefaultPolicy",
            "Statement": [
              {
                "Sid": "#{queue_arn}-Sid",
                "Effect": "Allow",
                "Principal": {
                  "AWS": "*"
                },
                "Action": "SQS:*",
                "Resource": "#{queue_arn}",
                "Condition": {
                  "StringEquals": {
                    "aws:SourceArn": "#{topic_arn}"
                  }
                }
              }
            ]
          }
        POLICY
      end
    end
  end
end
