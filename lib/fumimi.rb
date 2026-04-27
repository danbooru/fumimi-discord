require "dotenv"
Dotenv.load

class Fumimi; end

require "danbooru"
Dir[__dir__ + "/**/*.rb"].each { |file| require file }

require "active_support"
require "active_support/core_ext"
require "addressable/uri"
require "discordrb"

class Fumimi
  include Fumimi::ExceptionHandler

  attr_reader :server_id, :client_id, :token, :log, :booru, :cache, :initiate_shutdown, :censored_tags,
              :report_channel_name, :signoz_api_key

  def initialize(
    server_id:,
    client_id:,
    token:,
    booru_url: nil,
    booru_user: nil,
    booru_api_key: nil,
    reports_user: nil,
    reports_api_key: nil,
    report_channel_name: "user-reports",
    signoz_api_key: nil,
    censored_tags: [],
    log: Logger.new($stderr)
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

    @booru = Danbooru.new(url: booru_url, user: booru_user, api_key: booru_api_key, log: log, model_builder: method(:build_model))
    @cache = ActiveSupport::Cache::MemoryStore.new
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
      log: log,
      url: booru.url,
      user: @reports_user,
      api_key: @reports_api_key,
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

    register_commands
    bot.run(:async)

    monitor_reports

    loop do
      shutdown! if initiate_shutdown
      sleep 1
    end
  end

  def initiate_shutdown!
    @initiate_shutdown = true
  end
end
