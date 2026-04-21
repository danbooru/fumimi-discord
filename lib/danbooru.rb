require "active_support"
require "active_support/core_ext/string/inflections"
require "active_support/core_ext/hash/indifferent_access"
require "addressable/uri"
require_relative "http_client"

# Top-level Danbooru API client.
class Danbooru; end
Dir[__dir__ + "/danbooru/**/*.rb"].each { |file| require file }

class Danbooru
  attr_reader :url, :http

  # Resource-specific overrides. Any resource not listed here still works with
  # default URL and default query params via dynamic lookup.

  # rubocop:disable Layout/LineLength
  RESOURCE_OVERRIDES = {
    "BulkUpdateRequests" => { default_params: { only: "id,script,user,forum_topic,forum_post,created_at,status,tags" } },
    "Comments" => { default_params: { group_by: "comment", only: "id,body,created_at,creator,post,score" } },
    "Counts" => { url: "counts/posts", default_params: { limit: nil } },
    "ForumPosts" => { default_params: { only: "id,body,created_at,creator,topic,bulk_update_request,votes" } },
    "Posts" => { default_params: { limit: 200,
                                   only: "id,uploader,created_at,score,fav_count," \
                                         "tag_string,source,rating,parent_id,has_active_children," \
                                         "is_flagged,is_pending,is_deleted," \
                                         "media_asset", } },
    "RelatedTags" => { url: "related_tag" },
    "Tags" => { default_params: { "search[hide_empty]": "no",
                                  only: "id,name,is_deprecated,category,post_count,antecedent_alias,wiki_page,artist", } },
    "UserFeedback" => { url: "user_feedbacks" },
    "WikiPages" => { default_params: { only: "id,title,body,tag" } },

    "PostReports" => { url: "reports/posts" },
    "PostCounts" => { url: "counts/posts" },
    "ModerationReports" => { default_params: { only: "id,created_at,model[creator],model_type,model_id,creator,reason" } },
  }.freeze
  # rubocop:enable Layout/LineLength

  INCLUDE_MAP = {
    creator: "users",
    topic: "forum_topic",
  }.with_indifferent_access.freeze

  # @param url [String, nil] Danbooru base URL.
  # @param user [String, nil] Danbooru login.
  # @param api_key [String, nil] Danbooru API key.
  # @param log [Logger] Logger instance.
  # @param model_builder [#call] Callable used to construct model objects from API responses.
  def initialize(url: ENV["BOORU_URL"], # rubocop:disable Style/FetchEnvVar
                 user: ENV["BOORU_USER"], # rubocop:disable Style/FetchEnvVar
                 api_key: ENV["BOORU_API_KEY"], # rubocop:disable Style/FetchEnvVar
                 log: Logger.new($stderr),
                 model_builder: nil)
    url ||= "https://danbooru.donmai.us"

    log.info("Running on instance: #{url}, with user: '#{user}'")

    @url, @user, @api_key, @log = Addressable::URI.parse(url), user, api_key, log
    @http = HTTPClient.new(base: url, user: user, pass: api_key, log: log)
    @resources = {}
    @model_builder = model_builder || ->(**kwargs) { OpenStruct.new(**kwargs) }
  end

  # Construct a model instance (a post, user, comment, etc) from an API response.
  def build_model(resource_name:, attributes:, booru: self)
    @model_builder.call(resource_name:, attributes:, booru:)
  end

  # Returns a resource by name.
  #
  # @param name [String, Symbol]
  # @return [Danbooru::Resource]
  def [](name)
    class_name = name.to_s.camelize
    overrides = RESOURCE_OVERRIDES.fetch(class_name, {})

    @resources[class_name] ||= Resource.new(class_name.underscore, self, **overrides)
  end

  # Dynamically resolves booru.posts, booru.tags, booru.artist_commentary_versions, etc.
  def method_missing(method_name, *args, &block)
    return super unless args.empty? && block.nil? && method_name.to_s.match?(/\A[a-z_]+\z/)

    self[method_name]
  end

  # Marks snake_case resource names as supported dynamic methods.
  def respond_to_missing?(method_name, include_private = false)
    method_name.to_s.match?(/\A[a-z_]+\z/) || super
  end

  # Maps embedded response attributes to resource names.
  def self.map_attribute(attribute)
    INCLUDE_MAP[attribute]
  end
end
