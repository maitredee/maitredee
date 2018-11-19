module Maitredee
  module Adapters
    class TestAdapter
      def publish(message)
        messages << message
      end

      def messages
        @messages ||= []
      end

      def reset
        messages.clear
      end
    end
  end
end
