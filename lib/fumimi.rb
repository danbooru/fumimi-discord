require "dotenv"
Dotenv.load

require "zeitwerk"
require "active_support"
require "active_support/core_ext"
require "active_support/evented_file_update_checker"
require "active_support/string_inquirer"
require "addressable/uri"
require "discordrb"
require "rackup/handler/webrick"

class Fumimi
  mattr_reader :app_env, default: ActiveSupport::StringInquirer.new(ENV.fetch("APP_ENV", "development"))

  mattr_reader :loader, default: Zeitwerk::Loader.new.tap { |loader|
    loader.push_dir(__dir__)
    loader.inflector.inflect("dtext" => "DText", "http_client" => "HTTPClient")
    loader.enable_reloading if Fumimi.app_env.development?
    loader.logger = Logger.new($stderr, level: Logger::INFO)
    loader.setup
    loader.eager_load unless Fumimi.app_env.development?
  }

  include Fumimi::ExceptionHandler

  attr_reader :server_id, :client_id, :token, :log, :http, :booru, :cache, :webserver, :initiate_shutdown, :censored_tags,
              :report_channel_name, :signoz_api_key

  # Adapts the Discordrb logger to write through Fumimi's logger.
  DiscordLogStream = Struct.new(:log) do
    def puts(msg)
      level, thread, message = msg.to_s.match(/\A\[(\w+) : (\S+) @ [^\]]+\] (.*)/m)&.captures

      case level
      when "DEBUG", "OUT", "IN" then severity = Logger::DEBUG
      when "WARN", "RATELIMIT"  then severity = Logger::WARN
      when "ERROR"              then severity = Logger::ERROR
      else                           severity = Logger::INFO
      end

      log.add(severity) { "[discord/#{thread}] #{message}".strip }
    end

    def flush = nil
  end

  def initialize(
    server_id:,
    client_id:,
    token:,
    host: nil,
    port: nil,
    booru_url: nil,
    booru_user: nil,
    booru_api_key: nil,
    reports_user: nil,
    reports_api_key: nil,
    report_channel_name: "user-reports",
    signoz_api_key: nil,
    censored_tags: [],
    log: Logger.new(nil)
  )
    @server_id = server_id
    @client_id = client_id
    @token = token
    @reports_user = reports_user
    @reports_api_key = reports_api_key
    @report_channel_name = report_channel_name
    @signoz_api_key = signoz_api_key
    @censored_tags = censored_tags
    @log = log

    @http = HTTPClient.new.logger(log).timeout(30)
    @booru = Danbooru.new(url: booru_url, user: booru_user, api_key: booru_api_key, http: http, model_builder: method(:build_model))
    @cache = ActiveSupport::Cache::MemoryStore.new
    @webserver = Fumimi::Webserver.new(host: host, port: port, fumimi: self)

    Discordrb::LOGGER.streams = [DiscordLogStream.new(log)]
    Discordrb::LOGGER.mode = :info
  end

  def server
    bot.servers.fetch(@server_id)
  end

  def channels
    server.channels.index_by(&:name)
  end

  def shutdown!
    log.info("Shutting down...")
    bot.stop
    exit(0)
  end

  def pry
    require "pry"
    binding.pry # rubocop:disable Lint/Debugger
  end

  def bot
    @bot ||= Discordrb::Commands::CommandBot.new(
      name: "Robot Maid Fumimi",
      client_id: client_id,
      token: token,
      prefix: "/",
    )
  end

  def register_commands
    Fumimi::SlashCommand.register_all(fumimi: self)
    Fumimi::Event.register_all(fumimi: self)

    bot.button { |event| Fumimi::Button.mark_handled(event) }
  end

  def monitor_reports
    return unless [@reports_user, @reports_api_key].all?

    report_booru = Danbooru.new(
      url: booru.url,
      user: @reports_user,
      api_key: @reports_api_key,
      http: http,
      model_builder: ->(booru: nil, **kwargs) { build_model(booru: report_booru, **kwargs) },
    )

    report_monitor = Fumimi::ReportMonitor.new(fumimi: self, booru: report_booru)
    report_monitor.start
  end

  # Used by the Danbooru API client to build Fumimi::Model instances.
  #
  # @param resource_name [String] The model name (e.g. "post", "user", "comment", "wiki_page", etc).
  # @param attributes [Hash] The attributes for the model.
  # @param booru [Danbooru] The Danbooru API client.
  # @return [Fumimi::Model] The constructed model instance
  def build_model(resource_name:, attributes:, booru: self.booru)
    klass = "Fumimi::Model::#{resource_name.singularize.camelize}".safe_constantize || Fumimi::Model
    klass.new(resource_name:, attributes:, booru:, fumimi: self)
  end

  def run
    log.debug("Starting bot...")

    webserver.start
    register_commands
    bot.run(:async)

    monitor_reports

    loop do
      reload_changed_code!
      shutdown! if initiate_shutdown
      sleep 1
    end
  end

  def initiate_shutdown!
    @initiate_shutdown = true
  end

  private

  # @return [ActiveSupport::EventedFileUpdateChecker, nil] A file update checker that reloads code when changes are detected.
  def code_reloader
    return nil unless Fumimi.app_env.development?

    @code_reloader ||= ActiveSupport::EventedFileUpdateChecker.new([], { __dir__ => ["rb"] }) do
      log.info("Code changes detected. Reloading...")
      Fumimi.loader.reload
      log.info("Code reloaded.")
    end
  end

  def reload_changed_code!
    code_reloader&.execute_if_updated
  end
end
