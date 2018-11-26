require "integration_helper"
require "maitredee"
require "maitredee/adapters/sns_sqs_adapter"
Maitredee.client = :sns_sqs

RSpec.describe "Amazon SNS/SQS", :sns_sqs, :integration do
  let(:launcher) { Shoryuken::Launcher.new }

  before do
    Maitredee.configure_broker

    Shoryuken.add_group('default', 1)
    Shoryuken.add_queue(RecipeSubscriber.queue_resource_name, 1, 'default')
  end

  after do
    Maitredee.client.reset
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
