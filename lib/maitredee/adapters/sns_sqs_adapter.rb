require "aws-sdk-sns"
require "aws-sdk-sqs"

module Maitredee
  module Adapters
    class SnsSqsAdapter
      attr_reader :access_key_id, :secret_access_key, :region

      def initialize(access_key_id: nil, secret_access_key: nil, region: nil)
        @access_key_id = access_key_id || ENV["MAITREDEE_AWS_ACCESS_KEY_ID"]
        @secret_access_key = secret_access_key || ENV["MAITREDEE_AWS_SECRET_ACCESS_KEY"]
        @region = region || ENV["MAITREDEE_AWS_REGION"]
        Shoryuken.sqs_client = sqs_client
      end

      def publish(message)
        sns_client.publish(
          topic_arn: topics[message.topic_resource_name].arn,
          message: {
            topic_name: message.topic,
            event_name: message.event_name,
            primary_key: message.primary_key,
            schema_name: message.validation_schema,
            body: message.body,
            maitredee_version: Maitredee::VERSION
          }.to_json,
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
          hash[key] = Aws::SNS::Topic.new(topic.topic_arn, client: sns_client)
        end
      end

      def queues
        @queues ||= Hash.new do |hash, key|
          queue_url = sqs_client.create_queue(queue_name: key).queue_url
          hash[key] = Aws::SQS::Queue.new(queue_url, client: sqs_client)
        end
      end

      def subscriptions
        @subscriptions ||= {}
      end

      def subscribe(queue_resource_name:, topic_resource_name:)
        topic = topics[topic_resource_name]
        queue = queues[queue_resource_name]
        queue_arn = queue.attributes["QueueArn"]

        resp = sns_client.subscribe(
          topic_arn: topic.arn,
          protocol: "sqs",
          endpoint: queue_arn,
          attributes: { "RawMessageDelivery" => "true" }
        )

        subscriptions[resp.subscription_arn] =
          Aws::SNS::Subscription.new(resp.subscription_arn, client: sns_client)

        queue.set_attributes(
          attributes: {
            "Policy" => sqs_policy(
              queue_arn: queue_arn,
              topic_arn: topic.arn
            )
          }
        )
      end

      def reset
        [topics, queues, subscriptions].each do |resource|
          resource.values.each(&:delete)
          resource.clear
        end
      end

      private

      def sns_client
        @sns_client ||= new_client(Aws::SNS::Client)
      end

      def sqs_client
        @sqs_client ||= new_client(Aws::SQS::Client)
      end

      def new_client(klass)
        options = {}

        if access_key_id && secret_access_key
          options.merge!(
            access_key_id: access_key_id,
            secret_access_key: secret_access_key
          )
        end

        options[:region] = region if region

        klass.new(options)
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

      class Worker
        include Shoryuken::Worker

        class << self
          attr_accessor :subscriber_class
        end

        def perform(sqs_message, body)
          self.class.subscriber_class.process(sqs_message, body)
        end
      end
    end
  end
end
