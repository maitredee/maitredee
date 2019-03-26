class MenusSubscriber < Maitredee::Subscriber
  subscribe_to :menus do
    event(:upsert)
  end

  def upsert
    self.class.messages[:upsert] << message
  end

  def self.messages
    @messages ||= Hash.new { |hash, key| hash[key] = [] }
  end
end
