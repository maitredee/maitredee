require "bundler/setup"
require "pry"
require "dotenv/load"
require "maitredee"
require "maitredee/adapters/test_adapter"
require "aws-sdk-core"

if ENV["INTEGRATION_TEST"]
  Maitredee.client = ENV["INTEGRATION_TEST"].to_sym
else
  Maitredee.client = :test
end
Maitredee.resource_name_suffix = SecureRandom.hex(6)
Maitredee.schema_path = "spec/fixtures"
Maitredee.namespace = "test"
Maitredee.app_name = :maitredee

require "support/recipe"
require "support/recipe_delete_publisher"
require "support/recipe_publisher"
require "support/recipe_subscriber"

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  if ENV["INTEGRATION_TEST"]
    config.filter_run_excluding :test_client
  else
    config.filter_run_excluding :integration
  end

  config.before do |example|
    Aws.config[:stub_responses] = false
  end

  config.after do
    Maitredee.client.reset
  end
end
