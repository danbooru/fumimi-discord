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
  include Fumimi::Events

  attr_reader :server_id, :client_id, :token, :log, :bot, :server, :booru, :storage, :initiate_shutdown

  def initialize(server_id:, client_id:, token:, log: Logger.new($stderr))
    @server_id = server_id
    @client_id = client_id
    @token = token
    @log = log

    factory = {
      posts: Fumimi::Model::Post,
      tags: Fumimi::Model::Tag,
      comments: Fumimi::Model::Comment,
      forum_posts: Fumimi::Model::ForumPost,
      users: Fumimi::Model::User,
      wiki_pages: Fumimi::Model::WikiPage,
    }.with_indifferent_access

    @booru = Danbooru.new(factory: factory, log: log)
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
    log.debug("Registering bot commands...")

    bot.message(contains: Regexp.union(@@regex_listeners.pluck(:regex)), &method(:respond_to_embeds))

    bot.message(contains: %r{https?://\w+\.donmai\.us/posts/\d+}i, &method(:do_convert_post_links))
    bot.message(contains: %r{https?://\w+\.donmai\.us/users/\d+}i, &method(:do_convert_user_links))
    bot.command(:hi, description: "Say hi to Fumimi: `/hi`", &method(:do_hi))
    bot.command(:calc, description: "Calculate a math expression", &method(:do_calc))
    bot.command(:ruby, description: "Evaluate a ruby expression", &method(:do_ruby))
    bot.command(:comments, description: "List comments: `/comments <tags>`", &method(:do_comments))
    bot.command(:forum, description: "List forum posts: `/forum <text>`", &method(:do_forum))
    bot.command(:burs, description: "List BUR stats", &method(:do_burs))
    bot.command(:uploads, description: "List posts by year: `/uploads <search>`", &method(:do_upload_stats))
    bot.command(:uploaders, description: "List posts by uploader: `/uploaders <search>`", &method(:do_uploader_stats))
    bot.command(:approvers, description: "List posts by approver: `/approvers <search>`", &method(:do_approver_stats))
    bot.command(:stats, description: "Show various stats about a search: `/stats <search>`", &method(:do_search_stats))
    bot.command(:raffle, description: "Show the stats for a raffle: `/raffle <topic_id>`", &method(:do_raffle_report))
    bot.command(:rafflepick, description: "Pick raffle winners: `/rafflepick <topic_id> <n>`", &method(:do_raffle_pick))
    bot.command(:modqueue, description: "List modqueue stats: `/modqueue`", &method(:do_modqueue))
    bot.command(:downbooru, description: "Check if the site's up: `/downbooru`", &method(:do_downbooru))
    bot.command(:future, description: "Predict future post milestones", &method(:do_future))
    bot.command(:say, help_available: false, &method(:do_say))
  end

  def run_commands
    log.debug("Starting bot...")

    @bot = Discordrb::Commands::CommandBot.new(
      name: "Robot Maid Fumimi",
      client_id: client_id,
      token: token,
      prefix: "/"
    )

    register_commands
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
