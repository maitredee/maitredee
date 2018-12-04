require "spec_helper"
require "minitest/assertions"

RSpec.describe Maitredee::Publisher do
  describe ".call" do
    it "publisher will save a valid message", :test_client do
      recipe = Recipe.new(id: 1, name: "recipe name", servings: 2)
      message = RecipePublisher.call(recipe).first
      expect(message.primary_key).to eq recipe.id.to_s
      expect(Maitredee.client.messages.first.body["id"]).to eq recipe.id.to_s
    end

    it "raises errors if missing body" do
      recipe = Recipe.new(id: 1, name: "recipe name", servings: nil)
      expect {
        RecipePublisher.call(recipe)
      }.to raise_error(Maitredee::ValidationError)
    end
  end

  describe ".call_later" do
    include Minitest::Assertions
    prepend ActiveJob::TestHelper
    attr_writer :assertions

    def assertions
      @assertions ||= 0
    end

    around do |example|
      before_setup
      example.run
      after_teardown
    end

    def before_setup; end

    def after_teardown; end

    it "enqueues the job" do
      recipe = 1
      assert_enqueued_with(job: RecipePublisher.publisher_job) do
        RecipePublisher.call_later(recipe)
      end
    end

    it "enqueued job calls the service class" do
      recipe = 1
      expect(RecipePublisher).to receive(:call).with(recipe)
      RecipePublisher.publisher_job.perform_now(recipe)
    end
  end
end
