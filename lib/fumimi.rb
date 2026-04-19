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

  attr_reader :server_id, :client_id, :token, :log, :bot, :server, :booru, :cache, :initiate_shutdown

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

  def run_commands
    log.debug("Starting bot...")

    @bot = Discordrb::Commands::CommandBot.new(
      name: "Robot Maid Fumimi",
      client_id: client_id,
      token: token,
      prefix: "/"
    )

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

    bot.run(:async)

    loop do
      shutdown! if initiate_shutdown
      sleep 1
    end
  end

  def initiate_shutdown!
    @initiate_shutdown = true
  end
end
