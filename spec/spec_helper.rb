require "bundler/setup"
require "pry"
require "maitredee"
require "maitredee/adapters/test_adapter"
require "aws-sdk-core"

Maitredee.resource_name_suffix = SecureRandom.hex(6)
Maitredee.client = :test
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

  config.before do
    Aws.config[:stub_responses] = false
    Maitredee.client = :test
    Maitredee.schema_path = "spec/fixtures"
    Maitredee.namespace = "test"
  end
end
