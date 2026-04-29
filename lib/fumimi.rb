require "dotenv/load"
require "bundler/setup"
require "cgi/escape"

# The top-level module for the application. Initializes the library and handles code reloading. See Fumimi::Bot for the bot itself.
class Fumimi
  APP_ENV = ENV.fetch("APP_ENV", "development")
  Bundler.require(:default, APP_ENV.to_sym)

  # @return [String] The current application environment, e.g. "development", "production", "test".
  mattr_reader :app_env, default: ActiveSupport::StringInquirer.new(APP_ENV)

  # @return [Logger] The logger used throughout the application.
  mattr_accessor :log, default: Logger.new($stderr, level: Logger::INFO)

  # @return [Zeitwerk::Loader] The Zeitwerk code loader responsible for loading and reloading application code.
  mattr_reader :loader, default: Zeitwerk::Loader.new.tap { |loader|
    loader.push_dir(__dir__)
    loader.inflector.inflect("cli" => "CLI", "dtext" => "DText", "http_client" => "HTTPClient")
    loader.enable_reloading if app_env.development?
    loader.logger = log
    loader.setup
    loader.eager_load unless app_env.development?
  }

  # @return [ActiveSupport::EventedFileUpdateChecker, nil] A file update checker that reloads code when changes are detected.
  def self.code_reloader
    return nil unless app_env.development?

    @code_reloader ||= ActiveSupport::EventedFileUpdateChecker.new([], { __dir__ => ["rb"] }) do
      log.info("Code changes detected. Reloading...")
      loader.reload
      log.info("Code reloaded.")
    end
  end

  # @return [nil] Reloads code if changes are detected by the file update checker.
  def self.reload_changed_code!
    code_reloader&.execute_if_updated
  end
end
