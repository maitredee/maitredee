require "thor"
require "shoryuken/runner"

module Maitredee
  module CLI
    class Runner < Thor
      default_task :start

      desc 'start', 'Starts Maitredee'
      method_option :concurrency, aliases: '-c', type: :numeric, desc: 'Processor threads to use'
      method_option :daemon,      aliases: '-d', type: :boolean, desc: 'Daemonize process'
      method_option :subscribers, aliases: '-s', type: :array,   desc: 'Subscribers to process with optional weights'
      method_option :require,     aliases: '-r', type: :string,  desc: 'Dir or path of the workers'
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
          puts path
          fail ArgumentError, "The supplied config file #{path} does not exist" unless File.exist?(path)

          if (result = YAML.load(ERB.new(IO.read(path)).result))
            file = Tempfile.new(['maitredee-to-shoryuken', '.yml'])

            result.deep_symbolize_keys
            if result[:subscribers]
              subscribers = result.delete(:subscribers)
              result[:queues] = subscribers.map(&:constantize).map(&:queue_resource_name)
            end

            file.write(YAML.dump(result))
            file.flush

            opts[:config_file] = file.path
          end
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
    end
  end
end
