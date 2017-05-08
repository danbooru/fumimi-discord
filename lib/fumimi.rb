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
    @bot.run
  end
end
