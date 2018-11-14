module Adapters
  class TestAdapter
    def publish(message)
      messages << message
    end

    def messages
      @messages ||= []
    end

    def clear
      messages.clear
    end
  end
end
