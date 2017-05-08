require "fumimi/version"

require "active_support"
require "active_support/core_ext/hash/indifferent_access"
require "active_support/core_ext/object/to_query"
require "active_support/core_ext/object/blank"
require "active_support/core_ext/numeric/conversions"
require "addressable/uri"
require "discordrb"
require "dotenv"
require "pry"
require "pry-byebug"

Dotenv.load

class Danbooru
  class Resource < RestClient::Resource
    attr_accessor :type

    def type
      @type ||= OpenStruct
    end

    def default_params
      @default_params ||= { limit: 200 }
    end

    def with(params)
      resource = self.dup
      resource.default_params.merge!(params)
      resource
    end

    def search(params = {})
      params = params.transform_keys { |k| "search[#{k}]" }
      index(params)
    end

    def index(params)
      params = default_params.merge(params)
      params = "?" + params.to_query
      resp = self[params].get

      array = JSON.parse(resp.body)
      array.map { |hash| deserialize(hash) }
    end

    def show(id)
      resp = self[id].get
      hash = JSON.parse(resp.body)
      deserialize(hash)
    end

    def newest(since, limit = 50)
      items = index(limit: limit)
      items.select { |i| i.created_at >= since }
    end

    def deserialize(hash)
      hash = hash.map do |key, value|
        value =
          case key
          when "created_at", "updated_at", "last_commented_at", "last_comment_bumped_at", "last_noted_at"
            Time.parse(value) rescue nil
          when /_url$/
            Addressable::URI.parse(value)
          else
            value
          end
        [key, value]
      end.to_h

      type.new(hash)
    end
  end
end

class Danbooru
  class Post < OpenStruct
    def url
      "https://danbooru.donmai.us/posts/#{id}"
    end
  end
end

class Danbooru
  attr_reader :host, :user, :api_key, :site
  attr_reader :posts, :users, :comments, :forum_posts, :wiki, :tags

  def initialize(host: ENV["BOORU_HOST"], user: ENV["BOORU_USER"], api_key: ENV["BOORU_API_KEY"])
    @host, @user, @api_key = host, user, api_key

    @site = Danbooru::Resource.new(@host, {
      user: user,
      password: api_key,
      headers: { accept: :json },
    })

    @posts = @site["/posts"]
    @users = @site["/users"]
    @comments = @site["/comments"].with(group_by: :comment, "search[order]": :id_desc)
    @forum_posts = @site["/forum_posts"]
    @wiki = @site["/wiki_pages"]
    @tags = @site["/tags"]

    posts.type = Danbooru::Post
  end
end

class Fumimi
  attr_reader :bot, :booru, :log

  def initialize(client_id: nil, token: nil, log: Logger.new(STDERR))
    @log = RestClient.log = log

    @bot = Discordrb::Commands::CommandBot.new({
      name: "Robot Maid Fumimi",
      client_id: client_id,
      token: token,
      prefix: '/',
    })

    @booru = Danbooru.new

    register_commands
  end

  def shutdown!
    # log.info("Shutting down...")
    STDERR.puts "Shutting down..."
    exit(0)
  end

  def register_commands
    @bot.command(:random, description: "Show a random post") do |event, *args|
      "https://danbooru.donmai.us/posts/random"
    end
  end

  def run
    log.debug("Running bot...")

    bot.run(:async)
    event_loop
    bot.sync
  end

  def event_loop
    loop do
      last_checked_at = Time.now
      sleep 20

      notify_new_uploads(last_checked_at)
      notify_new_comments(last_checked_at)
      notify_new_forum_posts(last_checked_at)
    end
  end

  def notify_new_uploads(last_checked_at)
    log.debug("Checking /posts (#{last_checked_at}).")
    posts = booru.posts.newest(last_checked_at, 50)

    posts.each do |post|
      channels["testing"].send_message(post.url)
    end
  end

  def notify_new_comments(last_checked_at)
    log.debug("Checking /comments (#{last_checked_at}).")
    comments = booru.comments.newest(last_checked_at, 50)

    comments.each do |comment|
      channels["testing"].send_message("https://danbooru.donmai.us/comments/#{comment.id}")
    end
  end

  def notify_new_forum_posts(last_checked_at)
    log.debug("Checking /forum_posts (#{last_checked_at}).")
    forum_posts = booru.forum_posts.newest(last_checked_at, 50)

    forum_posts.each do |fp|
      channels["testing"].send_message("https://danbooru.donmai.us/forum_posts/#{fp.id}")
    end
  end
end
