require "rails"

module Maitredee
  # @private
  class Railtie < Rails::Railtie
    initializer "maitredee.initialization" do |app|
      if defined? ActiveJob
        require "maitredee/active_job"
      end
    end
  end
end
