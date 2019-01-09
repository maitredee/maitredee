module Maitredee
  module Adapters
    class TestAdapter < BaseAdapter
      # logs message published
      def publish(message)
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
    end
  end

  class Subscriber
    def self.test(
      body:,
      event_name: nil,
      message_id: SecureRandom.uuid,
      sent_at: Time.now,
      primary_key: nil
    )
      message = SubscriberMessage.new(
        topic_name: topic_name,
        body: body,
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
  end
end
