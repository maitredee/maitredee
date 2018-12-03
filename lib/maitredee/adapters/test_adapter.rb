module Maitredee
  module Adapters
    class TestAdapter
      def publish(message)
        messages << message
      end

      def messages
        @messages ||= []
      end

      def add_worker(subscriber_class)
      end

      def reset
        messages.clear
      end
    end
  end
end
