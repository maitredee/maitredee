require "spec_helper"

RSpec.describe "Amazon SNS/SQS", :sns_sqs do
  let(:launcher) { Shoryuken::Launcher.new }

  before do
    Aws.config[:stub_responses] = false
    Maitredee.client = :sns_sqs

    Maitredee.configure_broker

    queue = RecipeSubscriber.queue_resource_name

    Shoryuken.add_group('default', 1)
    Shoryuken.add_queue(queue, 1, 'default')

    Shoryuken.register_worker(queue, RecipeSubscriber::RecipeSubscriberWorker)
  end

  after do
    Aws.config[:stub_responses] = true

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
