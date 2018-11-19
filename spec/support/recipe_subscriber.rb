class RecipeSubscriber < Maitredee::Subscriber
  subscribe_to :recipes do
    event(:delete, to: :delete)
    event(nil, to: :process)
  end

  def process
    self.class.messages[:process] << message
  end

  def delete
    self.class.messages[:delete] << message
  end

  def self.messages
    @messages ||= Hash.new { |hash, key| hash[key] = [] }
  end
end
