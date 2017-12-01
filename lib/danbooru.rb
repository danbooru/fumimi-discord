require "addressable"
require "rest-client"

require "danbooru/resource"
require "danbooru/comment"
require "danbooru/forum_post"
require "danbooru/post"
require "danbooru/tag"
require "danbooru/wiki_page"
require "danbooru/iqdb_query"

class Danbooru
  RESOURCES = %i[
    bans comments iqdb_queries forum_posts forum_topics pools posts source tags users wiki_pages
  ]

  attr_reader :host, :user, :api_key, :site
  attr_reader *RESOURCES.map(&:to_sym) # attr_reader :bans, :comments, ...
  attr_reader :count

  def initialize(host: ENV["BOORU_HOST"], user: ENV["BOORU_USER"], api_key: ENV["BOORU_API_KEY"], factory: {})
    @user, @api_key = user, api_key
    @host = Addressable::URI.parse(host)

    @site = Danbooru::Resource.new(@host, {
      user: user,
      password: api_key,
      headers: { accept: :json },
    })

    RESOURCES.each do |name|
      # @posts = @site["/posts"]
      instance_variable_set("@#{name}", @site["/#{name}"])

      # posts.booru = self
      send(name).booru = self

      # posts.factory = factory["posts"] || Danbooru::Post
      default_factory = "Danbooru::#{name.to_s.singularize.camelize}".safe_constantize || Danbooru::Model
      send(name).factory = factory[name] || default_factory
    end

    comments.with(group_by: :comment)
    tags.with("search[hide_empty]": "no")
    @counts = @site["/counts/posts"]
  end
end
