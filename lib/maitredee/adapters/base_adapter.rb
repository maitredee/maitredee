module Maitredee
  module Adapters
    class BaseAdapter
      def publish(message)
        raise NotImplementedError
      end

      def add_worker(subscriber_class)
        raise NotImplementedError
      end

      def reset
        raise NotImplementedError
      end
    end
  end
end

