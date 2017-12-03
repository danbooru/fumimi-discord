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

  attr_reader :host, :site, :site_params
  attr_reader *RESOURCES

  def initialize(host: ENV["BOORU_HOST"], user: ENV["BOORU_USER"], api_key: ENV["BOORU_API_KEY"], factory: {}, logger: nil)
    @host = Addressable::URI.parse(host)
    @site_params = {
      user: user,
      password: api_key,
      headers: { accept: :json },
      log: logger,
    }

    @site = Danbooru::Resource.new(host, site_params.merge(booru: self))

    RESOURCES.each do |name|
      resource_name = name.to_s.camelize
      model_name = name.to_s.singularize.camelize
      resource_class = "Danbooru::Resource::#{resource_name}".safe_constantize || Danbooru::Resource
      factory_class = factory[name] || "Danbooru::Model::#{model_name}".safe_constantize || Danbooru::Model
      url = host + "/" + name.to_s

      # @posts = Danbooru::Resource::Post(url, booru: self, factory: Danbooru::Model::Post, **site_params)
      resource = resource_class.new(url, site_params.merge(booru: self, factory: factory_class))
      instance_variable_set("@#{name}", resource)
    end
  end
end
