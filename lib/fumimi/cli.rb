class Fumimi
  # Command-line interface for running Fumimi.
  class CLI
    attr_reader :argv, :env, :stdout, :stderr, :options, :log

    # @param argv [Array<String>] The command-line arguments passed to the CLI.
    # @param env [Hash] The environment variables to use.
    # @param stdout [IO] The output stream to write to.
    # @param stderr [IO] The error stream to write to.
    def initialize(argv = ARGV, env: ENV, stdout: $stdout, stderr: $stderr)
      @argv = argv.dup
      @env = env
      @stdout = stdout
      @stderr = stderr
      @options = {}
      @log = Logger.new(@stderr)
      @log.level = env.fetch("FUMIMI_LOG_LEVEL", "info")
    end

    # @return [Boolean] Runs the CLI and returns true if the command succeeded, false if it failed with an error.
    def self.run!(...)
      new(...).run!
    end

    # @return [Boolean] Runs the CLI and returns true if the command succeeded, false if it failed with an error.
    def run!
      parse_options
      fumimi = Fumimi::Bot.new(log: log, env: env)
      fumimi.run
    rescue SystemExit => e
      e.success?
    rescue StandardError => e
      @stderr.puts "Error: #{e.message}"
      false
    end

    private

    # Parses CLI flags into the options hash.
    def parse_options
      OptionParser.new do |opts|
        program_name = File.basename($PROGRAM_NAME)

        opts.banner = <<~EOS
          #{program_name} - Danbooru Discord bot

          Usage: #{program_name} [options]
        EOS

        opts.on("-h", "--help", "Show this help message") do
          @stdout.puts opts
          exit(0)
        end

        opts.on("-v", "--verbose", "Set log level to debug") do
          @log.level = Logger::DEBUG
        end

        opts.on("-l", "--log-level LEVEL", %w[debug info warn error fatal], "Set log level (debug, info, warn, error, fatal)") do |level|
          @log.level = Logger.const_get(level.upcase)
        end

        opts.parse!(@argv, into: @options)
      end
    end
  end
end
