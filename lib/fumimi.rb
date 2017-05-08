require "fumimi/version"

require "active_support"
require "active_support/core_ext/hash/indifferent_access"
require "active_support/core_ext/object/to_query"
require "active_support/core_ext/object/blank"
require "active_support/core_ext/numeric/conversions"
require "discordrb"
require "dotenv"
require "pry"
require "pry-byebug"

Dotenv.load

class Danbooru
  class Resource < RestClient::Resource
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

      json = JSON.parse(resp.body)
      json.map { |item| OpenStruct.new(item) }
    end

    def show(id)
      resp = self[id].get
      json = JSON.parse(resp.body)
      OpenStruct.new(json)
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
