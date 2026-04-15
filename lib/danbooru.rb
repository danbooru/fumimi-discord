require "active_support"
require "active_support/core_ext/string/inflections"
require "active_support/core_ext/hash/indifferent_access"
require "addressable/uri"
require_relative "http_client"

# Top-level Danbooru API client.
class Danbooru; end
Dir[__dir__ + "/danbooru/**/*.rb"].each { |file| require file }

class Danbooru
  attr_reader :url, :user, :api_key, :log, :http, :resources, :factory

  RESOURCES = {
    "AliasAndImplicationImports" => { url: "admin/alias_and_implication_import" },
    "AdminUsers" => { url: "admin/users" },
    "MaintenanceUserApiKey" => { url: "maintenance/user/api_key" },
    "MaintenanceUserDeletion" => { url: "maintenance/user/deletion" },
    "MaintenanceUserDmailFilter" => { url: "maintenance/user/dmail_filter" },
    "MaintenanceUserEmailChange" => { url: "maintenance/user/email_change" },
    "MaintenanceUserEmailNotification" => { url: "maintenance/user/email_notification" },
    "MaintenanceUserLoginReminder" => { url: "maintenance/user/login_reminder" },
    "MaintenanceUserPasswordReset" => { url: "maintenance/user/password_reset" },
    "ModeratorBulkRevert" => { url: "moderator/bulk_revert" },
    "ModeratorInvitations" => { url: "moderator/invitations" },
    "ModeratorIpAddrs" => { url: "moderator/ip_addrs" },
    "ModeratorTag" => { url: "moderator/tag" },
    "ExplorePosts" => { url: "explore/posts" },
    "ArtistCommentaries" => {},
    "ArtistCommentaryVersions" => {},
    "Artists" => {},
    "ArtistVersions" => {},
    "Bans" => {},
    "BulkUpdateRequests" => { default_params: { only: "id,script,user,forum_topic,forum_post,created_at,status,tags" } },
    "Comments" => { default_params: { group_by: "comment", only: "id,body,created_at,creator,post,score" } },
    "CommentVotes" => {},
    "Counts" => { url: "counts/posts", default_params: { limit: nil } },
    "DelayedJobs" => {},
    "Dmails" => {},
    "DtextPreviews" => {},
    "FavoriteGroups" => {},
    "Favorites" => {},
    "ForumPosts" => { default_params: { only: "id,body,created_at,creator,topic,bulk_update_request,votes" } },
    "ForumTopics" => {},
    "IpBans" => {},
    "IqdbQueries" => {},
    "JanitorTrials" => {},
    "ModActions" => {},
    "Modqueue" => {},
    "NewsUpdates" => {},
    "Notes" => {},
    "NotePreviews" => {},
    "NoteVersions" => {},
    "Pools" => {},
    "PoolElements" => {},
    "PoolVersions" => {},
    "Posts" => { default_params: { limit: 200,
                                   only: "id,uploader,created_at,score,fav_count," \
                                         "tag_string,source,rating,parent_id,has_active_children," \
                                         "is_flagged,is_pending,is_deleted," \
                                         "media_asset", } },
    "PostAppeals" => {},
    "PostApprovals" => {},
    "PostDisapprovals" => {},
    "PostEvents" => {},
    "PostFlags" => {},
    "PostReplacements" => {},
    "PostVersions" => {},
    "PostVotes" => {},
    "RelatedTags" => { url: "related_tag" },
    "SavedSearches" => {},
    "Source" => {},
    "TagAliases" => {},
    "TagImplications" => {},
    "Tags" => { default_params: { "search[hide_empty]": "no",
                                  only: "id,name,is_deprecated,category,post_count,antecedent_alias,wiki_page,artist", } },
    "Uploads" => {},
    "Users" => {},
    "UserFeedback" => { url: "user_feedbacks" },
    "UserNameChangeRequests" => {},
    "UserRevert" => {},
    "WikiPages" => { default_params: { only: "id,title,body,tag" } },
    "WikiPageVersions" => {},

    "PostReports" => { url: "reports/posts" },
  }.freeze

  INCLUDE_MAP = {
    creator: "users",
    topic: "forum_posts",
  }.with_indifferent_access.freeze

  # @param url [String, nil] Danbooru base URL.
  # @param user [String, nil] Danbooru login.
  # @param api_key [String, nil] Danbooru API key.
  # @param factory [Hash] Model overrides keyed by resource name.
  # @param log [Logger] Logger instance.
  def initialize(url: ENV["BOORU_URL"], # rubocop:disable Style/FetchEnvVar
                 user: ENV["BOORU_USER"], # rubocop:disable Style/FetchEnvVar
                 api_key: ENV["BOORU_API_KEY"], # rubocop:disable Style/FetchEnvVar
                 factory: {},
                 log: Logger.new($stderr))
    url ||= "https://danbooru.donmai.us"

    log.info("Running on instance: #{url}, with user: '#{user}'")

    @url, @user, @api_key, @log = Addressable::URI.parse(url), user, api_key, log
    @http = HTTPClient.new(base: url, user: user, pass: api_key, log: log)
    @factory, @resources = factory.with_indifferent_access, {}
  end

  # Simple health check against the posts endpoint.
  #
  # @return [Danbooru::Response]
  def ping(params = {})
    posts.ping(params)
  end

  # Checks if configured credentials can authenticate successfully.
  #
  # @return [Boolean]
  def logged_in?
    return false unless user.present? && api_key.present?

    users.index(name: user).succeeded?
  end

  # Returns a resource by name.
  #
  # @param name [String, Symbol]
  # @return [Danbooru::Resource]
  def [](name)
    name = name.to_s.camelize

    raise ArgumentError, "invalid resource name '#{name}'" unless RESOURCES.has_key?(name)

    resources[name] ||= build_resource(name)
  end

  RESOURCES.keys.each do |name|
    Resource.const_set(name, Class.new(Resource)) unless Resource.const_defined?(name)

    define_method(name.underscore) do
      self[name]
    end
  end

  # Maps embedded response attributes to resource names.
  def self.map_attribute(attribute)
    INCLUDE_MAP[attribute]
  end

  private

  # Instantiates a resource object for a given entry in `RESOURCES`.
  #
  # @param class_name [String]
  # @return [Danbooru::Resource]
  def build_resource(class_name)
    Resource.const_get(class_name).new(class_name.underscore, self, **RESOURCES[class_name])
  end
end
