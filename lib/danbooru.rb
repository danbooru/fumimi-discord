require "active_support"
require "active_support/core_ext/string/inflections"
require "addressable/uri"
require "rest-client"

Dir[__dir__ + "/danbooru/**/*.rb"].each { |file| require file }

class Danbooru
  RESOURCES = %i[
    artist_commentaries artist_commentary_versions artists artist_versions bans
    bulk_update_requests comments comment_votes counts delayed_jobs dmails
    dtext_previews favorite_groups favorites forum_posts forum_topics ip_bans
    iqdb_queries mod_actions notes note_previews note_versions pools
    pool_versions posts post_appeals post_flags post_replacements post_versions
    post_votes related_tags saved_searches source tag_aliases tag_implications
    tags uploads users user_feedbacks wiki_pages wiki_page_versions
  ]

  attr_reader :host, :user, :api_key, :site
  attr_reader *RESOURCES

  def initialize(host: ENV["BOORU_HOST"], user: ENV["BOORU_USER"], api_key: ENV["BOORU_API_KEY"], factory: {}, logger: nil)
    @user, @api_key = user, api_key
    @host = Addressable::URI.parse(host)

    @site = Danbooru::Resource.new(@host, {
      user: user,
      password: api_key,
      headers: { accept: :json },
      log: logger,
    })

    RESOURCES.each do |name|
      # @posts = @site["/posts"]
      instance_variable_set("@#{name}", @site["/#{name}"])

      # posts.booru = self
      send(name).booru = self

      # posts.factory = factory["posts"] || Danbooru::Post
      default_factory = "Danbooru::Model::#{name.to_s.singularize.camelize}".safe_constantize || Danbooru::Model
      send(name).factory = factory[name] || default_factory
    end

    comments.with(group_by: :comment)
    tags.with("search[hide_empty]": "no")
    @counts = @site["/counts/posts"]
  end
end
