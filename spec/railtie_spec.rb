require "spec_helper"
require "minitest/assertions"
require "rails"
require "active_job"
require "maitredee/railtie"

RSpec.describe Maitredee::Railtie do
  before :all do
    Maitredee::Railtie.initializers.each(&:run)
  end

  describe "Maitredee::Publisher.call_later" do
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
      assert_enqueued_with(job: RecipePublisher::PublisherJob) do
        RecipePublisher.call_later(recipe)
      end
    end

    it "enqueued job calls the service class" do
      recipe = 1
      expect(RecipePublisher).to receive(:call).with(recipe)
      RecipePublisher::PublisherJob.perform_now(recipe)
    end
  end

  it "Maitredee::ActiveJob#inherited" do
    test_job = Class.new(Maitredee::Publisher)
    expect(test_job.respond_to?(:call_later)).to be true
  end
end
