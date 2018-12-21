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
end
