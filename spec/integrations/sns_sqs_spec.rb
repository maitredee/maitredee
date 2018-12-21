RSpec.describe "Amazon SNS/SQS", :sns_sqs, :integration do
  class NoOptionsSubscriber < Maitredee::Subscriber
    subscribe_to :no_options do
      default_event to: :default
    end
  end

  it "has default options" do
    options = Maitredee::Adapters::SnsSqsAdapter::NoOptionsSubscriberWorker.shoryuken_options_hash
    expect(options["queue"]).to eq "test--no_options--maitredee--no-options--#{Maitredee.resource_name_suffix}"
    expect(options["auto_delete"]).to be true
    expect(options["body_parser"]).to be :json
  end

  context "live sns sqs account" do
    let(:launcher) { Shoryuken::Launcher.new }

    before do
      Aws.config[:stub_responses] = false

      Maitredee.configure_broker

      queue = RecipeSubscriber.queue_resource_name

      Shoryuken.add_group('default', 1)
      Shoryuken.add_queue(queue, 1, 'default')

      Shoryuken.register_worker(queue, Maitredee::Adapters::SnsSqsAdapter::RecipeSubscriberWorker)
    end

    after do
      Aws.config[:stub_responses] = true
    end

    let(:recipe) { Recipe.new(id: 1, name: "recipe name", servings: 2) }

    it "sends and recieves messages" do
      RecipePublisher.call(recipe)
      sent_message = RecipeDeletePublisher.call(recipe).first

      poll_queues_until { RecipeSubscriber.messages.values.flatten.size >= 2 }

      expect(RecipeSubscriber.messages[:process].size).to eq 1
      expect(RecipeSubscriber.messages[:delete].size).to eq 1

      recieved_message = RecipeSubscriber.messages[:delete].first

      expect(sent_message.body).to eq recieved_message.body
      expect(sent_message.topic_name).to eq recieved_message.topic_name
      expect(sent_message.event_name).to eq recieved_message.event_name
      expect(sent_message.primary_key).to eq recieved_message.primary_key
      expect(sent_message.schema_name).to eq recieved_message.schema_name
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
end
