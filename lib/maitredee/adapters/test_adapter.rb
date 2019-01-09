require "bigdecimal"

module Maitredee
  module Adapters
    class TestAdapter < BaseAdapter
      # @private
      PERMITTED_TYPES = [NilClass, String, Integer, Float, BigDecimal, TrueClass, FalseClass].freeze

      # logs message published
      def publish(message)
        message = message.dup
        message.body = self.class.serialize_argument(message.body)
        messages << message
      end

      # returns all messages that have been published since last #reset
      def messages
        @messages ||= []
      end

      # no-op
      def add_worker(subscriber_class)
      end

      # resets messages logged
      def reset
        messages.clear
      end

      # @api private
      def self.serialize_argument(argument)
        case argument
        when *PERMITTED_TYPES
          argument
        when Array
          argument.each { |arg| serialize_argument(arg) }
        when Hash
          result = argument.each_with_object({}) do |(key, value), hash|
            hash[key.to_s] = serialize_argument(value)
          end
          result
        else
          raise ArgumentError, "#{argument} is an invalid json type"
        end
      end

      module SubscriberTesting
        # simple api to test subscribers
        # ```
        #   RecipeSubscriber.test(body: { id: 1 })
        # ```
        def test(
          body:,
          event_name: nil,
          message_id: SecureRandom.uuid,
          sent_at: Time.now,
          primary_key: nil
        )
          message = SubscriberMessage.new(
            topic_name: topic_name,
            body: TestAdapter.serialize_argument(body),
            event_name: event_name,
            message_id: message_id,
            sent_at: sent_at.to_i,
            primary_key: primary_key,
            schema_name: nil,
            broker_message_id: message_id,
            maitredee_version: Maitredee::VERSION,
            raw_message: nil,
            adapter_message: nil
          )
          process(message)
        end

        ::Maitredee::Subscriber.extend(SubscriberTesting)
      end
    end
  end
end
