require "dotenv"
Dotenv.load

class Fumimi; end

require "danbooru"
Dir[__dir__ + "/**/*.rb"].each { |file| require file }

require "active_support"
require "active_support/core_ext"
require "dentaku"
require "discordrb"
require "open-uri"
require "addressable/uri"

require "optparse"
require "shellwords"

class Fumimi
  include Fumimi::ExceptionHandler
  include Fumimi::Commands

  attr_reader :server_id, :client_id, :token, :log, :bot, :server, :booru, :storage, :initiate_shutdown

  def initialize(server_id:, client_id:, token:, log: Logger.new($stderr))
    @server_id = server_id
    @client_id = client_id
    @token = token
    @log = log

    @booru = Danbooru.new(log: log)
    # @storage = Google::Cloud::Storage.new
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

  def register_commands
    bot.command(:related, description: "List related tags: `/related <category> <search>`", &method(:do_related_tags))
    bot.command(:uploads, description: "List posts by year: `/uploads <search>`", &method(:do_upload_stats))
    bot.command(:uploaders, description: "List posts by uploader: `/uploaders <search>`", &method(:do_uploader_stats))
    bot.command(:stats, description: "Show various stats about a search: `/stats <search>`",
                &method(:do_post_search_stats))
    bot.command(:searches, description: "Check unique IPs for a tag search: `/searches cat_ears [hour|day]",
                &method(:do_searches))
    bot.command(:allsearches, help_available: false, &method(:do_allsearches)) # only for admins
    bot.command(:ruby, description: "Evaluate a ruby expression", &method(:do_ruby))
    bot.command(:say, help_available: false, &method(:do_say))
  end

  def cache
    @cache ||= Zache.new
  end

  def run_commands
    log.debug("Starting bot...")

    @bot = Discordrb::Commands::CommandBot.new(
      name: "Robot Maid Fumimi",
      client_id: client_id,
      token: token,
      prefix: "/"
    )

    Fumimi::SlashCommand.register_all(bot: bot, server_id: server_id, log: log, booru: @booru, cache: cache)
    Fumimi::Event.register_all(bot: bot, log: log, booru: @booru, cache: cache)
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
