require "maitredee/cli/runner"

RSpec.describe Maitredee::CLI::Runner do
  before do
    allow(Shoryuken::Runner.instance).to receive(:run)
  end

  it "correctly gets queue names from options" do
    args = %w(start -s RecipeSubscriber)
    options = described_class.start(args)
    expect(options).to eq(queues: ["test--recipes--maitredee--recipe--#{Maitredee.resource_name_suffix}"])
  end

  it "correctly gets queue names from config" do
    file = Tempfile.new(['maitredee', '.yml'])
    file.write(YAML.dump({ "delay" => 25, "subscribers" => ["RecipeSubscriber"] }))
    file.flush
    args = %W(start -C #{file.path})
    options = described_class.start(args)
    config = YAML.load(File.read(options[:config_file])).deep_symbolize_keys
    expect(config).to eq(delay: 25)
    expect(options[:queues]).to eq(["test--recipes--maitredee--recipe--#{Maitredee.resource_name_suffix}"])
  end

  it "configured correctly to allow server to be configured" do
    block_executed = false

    Shoryuken.configure_server do |config|
      block_executed = true
    end

    expect(block_executed).to be true
  end
end
