require "integration_helper"
require "maitredee"
require "maitredee/adapters/rabbitmq_adapter"
Maitredee.client = :rabbitmq

RSpec.describe "RabbitMQ", :rabbitmq, :integration do
  let(:launcher) { Hutch::Launcher.new } # ?????????????????

  before do
    Maitredee.client.reset
    # Maitredee.configure_broker
  end

  let(:recipe) { Recipe.new(id: 1, name: "recipe name", servings: 2) }

  it "sends and recieves messages" do
    RecipePublisher.call(recipe)
    RecipeDeletePublisher.call(recipe)

    poll_queues_until { RecipeSubscriber.messages.values.flatten.size >= 2 }

    expect(RecipeSubscriber.messages[:process].size).to eq 1
    expect(RecipeSubscriber.messages[:delete].size).to eq 1
  end

  def poll_queues_until
    launcher.start

    Timeout::timeout(10) do
      begin
        sleep 0.5
      end until yield
    end
  ensure
    launcher.stop
  end
end
