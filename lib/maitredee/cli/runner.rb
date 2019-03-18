require "thor"
require "shoryuken/runner"

# ensures server configurations are executed
# @private
module Shoryuken
  module CLI
  end
end

module Maitredee
  module CLI
    class Runner < Thor
      default_task :start

      desc 'start', 'Starts Maitredee'
      method_option :concurrency, aliases: '-c', type: :numeric, desc: 'Processor threads to use'
      method_option :daemon,      aliases: '-d', type: :boolean, desc: 'Daemonize process'
      method_option :subscribers, aliases: '-s', type: :array,   desc: 'Subscribers to process with optional weights'
      method_option :require,     aliases: '-r', type: :string,  desc: 'Dir or path of the subscribers'
      method_option :timeout,     aliases: '-t', type: :numeric, desc: 'Hard shutdown timeout'
      method_option :config,      aliases: '-C', type: :string,  desc: 'Path to config file'
      method_option :config_file,                type: :string,  desc: 'Path to config file (backwards compatibility)'
      method_option :rails,       aliases: '-R', type: :boolean, desc: 'Load Rails'
      method_option :logfile,     aliases: '-L', type: :string,  desc: 'Path to logfile'
      method_option :pidfile,     aliases: '-P', type: :string,  desc: 'Path to pidfile'
      method_option :verbose,     aliases: '-v', type: :boolean, desc: 'Print more verbose output'
      method_option :delay,       aliases: '-D', type: :numeric, desc: 'Number of seconds to pause fetching from an empty queue'
      def start
        opts = options.to_h.symbolize_keys

        say '[DEPRECATED] Please use --config instead of --config-file', :yellow if opts[:config_file]

        opts[:config_file] = opts.delete(:config) if opts[:config]

        if opts[:config_file]
          path = opts.delete(:config_file)
          fail ArgumentError, "The supplied config file #{path} does not exist" unless File.exist?(path)

          if (result = YAML.load(ERB.new(IO.read(path)).result))
            file = Tempfile.new(['maitredee-to-shoryuken', '.yml'])

            result.deep_symbolize_keys!

            if result[:rails]
              opts[:rails] = result.delete(:rails)
            end

            if result[:subscribers]
              opts[:subscribers] ||= []
              opts[:subscribers] += result.delete(:subscribers)
            end

            file.write(YAML.dump(result))
            file.flush

            opts[:config_file] = file.path
          end
        end

        if opts[:rails]
          opts.delete(:rails)
          load_rails
        end

        if opts[:require]
          require_workers(opts.delete(:require))
        end

        if opts[:subscribers]
          opts[:queues] = opts.delete(:subscribers).map(&:constantize).map(&:queue_resource_name)
        end

        fail_task "You should set a logfile if you're going to daemonize" if opts[:daemon] && opts[:logfile].nil?

        Shoryuken::Runner.instance.run(opts.freeze)

        opts
      end

      desc 'version', 'Prints version'
      def version
        say "Maitredee #{Maitredee::VERSION}"
        say "Shoryuken #{Shoryuken::VERSION}"
      end

      no_commands do
        def load_rails
          # Adapted from: https://github.com/mperham/sidekiq/blob/master/lib/sidekiq/cli.rb

          require 'rails'
          if ::Rails::VERSION::MAJOR < 4
            require File.expand_path('config/environment.rb')
            ::Rails.application.eager_load!
          else
            # Painful contortions, see 1791 for discussion
            require File.expand_path('config/application.rb')
            if ::Rails::VERSION::MAJOR == 4
              ::Rails::Application.initializer 'maitredee.eager_load' do
                ::Rails.application.config.eager_load = true
              end
            end
            require 'shoryuken/extensions/active_job_adapter' if Shoryuken.active_job?
            require File.expand_path('config/environment.rb')
          end
        end

        def require_workers(required)
          return unless required

          if File.directory?(required)
            Dir[File.join(required, '**', '*.rb')].each(&method(:require))
          else
            require required
          end
        end
      end
    end
  end
end
