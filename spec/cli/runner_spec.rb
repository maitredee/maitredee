require "maitredee/cli/runner"

RSpec.describe Maitredee::CLI::Runner do
  before do
    allow(Shoryuken::Runner.instance).to receive(:run)
  end

  it "correctly gets queue names from options" do
    args = %w(start -s RecipeSubscriber MenusSubscriber)

    allow(Shoryuken::Runner.instance).to receive(:run) do |options|
      config = YAML.load(File.read(options[:config_file])).deep_symbolize_keys
      expect(config).to eq(
        queues: [
          "test--recipes--maitredee--recipe--#{Maitredee.resource_name_suffix}",
          "test--menus--maitredee--menus--#{Maitredee.resource_name_suffix}"
        ]
      )
    end

    described_class.start(args)

    expect(Shoryuken::Runner.instance).to have_received(:run)
  end

  it "correctly gets queue names from config" do
    file = Tempfile.new(['maitredee', '.yml'])
    file.write(YAML.dump({ "delay" => 25, "subscribers" => ["RecipeSubscriber", "MenusSubscriber"] }))
    file.flush
    args = %W(start -C #{file.path})

    allow(Shoryuken::Runner.instance).to receive(:run) do |options|
      config = YAML.load(File.read(options[:config_file])).deep_symbolize_keys
      expect(config).to eq(
        delay: 25,
        queues: [
          "test--recipes--maitredee--recipe--#{Maitredee.resource_name_suffix}",
          "test--menus--maitredee--menus--#{Maitredee.resource_name_suffix}"
        ]
      )
    end

    described_class.start(args)

    expect(Shoryuken::Runner.instance).to have_received(:run)
  end

  it "configured correctly to allow server to be configured" do
    block_executed = false

    Shoryuken.configure_server do |config|
      block_executed = true
    end

    expect(block_executed).to be true
  end
end
