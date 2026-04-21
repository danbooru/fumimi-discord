require "dotenv"
Dotenv.load

class Fumimi; end

require "danbooru"
Dir[__dir__ + "/**/*.rb"].each { |file| require file }

require "active_support"
require "active_support/core_ext"
require "addressable/uri"
require "discordrb"
require "zache"

class Fumimi
  include Fumimi::ExceptionHandler

  attr_reader :server_id, :client_id, :token, :log, :booru, :cache, :initiate_shutdown

  def initialize(server_id:, client_id:, token:, log: Logger.new($stderr))
    @server_id = server_id
    @client_id = client_id
    @token = token
    @log = log

    @booru = Danbooru.new(log: log)
    @cache = Zache.new
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
      prefix: "/"
    )
  end

  def register_commands
    Fumimi::SlashCommand.register_all(
      bot: bot,
      server_id: server_id,
      log: log,
      booru: booru,
      cache: cache
    )
    Fumimi::Event.register_all(
      bot: bot,
      log: log,
      booru: booru,
      cache: cache
    )

    bot.button { |event| Fumimi::Button.mark_handled(event) }
  end

  def monitor_reports
    reports_user = ENV.fetch("BOORU_REPORTS_USER", nil)
    reports_api_key = ENV.fetch("BOORU_REPORTS_API_KEY", nil)

    return unless [reports_user, reports_api_key].all?

    report_booru = Danbooru.new(log: log,
                                user: reports_user,
                                api_key: reports_api_key)

    report_monitor = Fumimi::ReportMonitor.new(booru: report_booru,
                                               log: log,
                                               bot: bot)
    report_monitor.start
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
