require "active_support"
require "active_support/core_ext/string/inflections"
require "active_support/core_ext/hash/indifferent_access"
require "addressable/uri"

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
    "ModeratorPostApproval" => { url: "moderator/post/approval" },
    "ModeratorPostDisapproval" => { url: "moderator/post/disapproval" },
    "ModeratorPostQueue" => { url: "moderator/post/queue" },
    "ModeratorPostPosts" => { url: "moderator/post/posts" },
    "ExplorePosts" => { url: "explore/posts" },
    "ArtistCommentaries" => {},
    "ArtistCommentaryVersions" => {},
    "Artists" => {},
    "ArtistVersions" => {},
    "Bans" => {},
    "BulkUpdateRequests" => {},
    "Comments" => { default_params: { group_by: "comment", only: "id,body,created_at,creator,post" } },
    "CommentVotes" => {},
    "Counts" => { url: "counts/posts", default_params: { limit: nil } },
    "DelayedJobs" => {},
    "Dmails" => {},
    "DtextPreviews" => {},
    "FavoriteGroups" => {},
    "Favorites" => {},
    "ForumPosts" => { default_params: { only: "id,body,created_at,creator,topic" } },
    "ForumTopics" => {},
    "IpBans" => {},
    "IqdbQueries" => {},
    "JanitorTrials" => {},
    "ModActions" => {},
    "NewsUpdates" => {},
    "Notes" => {},
    "NotePreviews" => {},
    "NoteVersions" => {},
    "Pools" => {},
    "PoolElements" => {},
    "PoolVersions" => {},
    "Posts" => { default_params: { limit: 200 } },
    "PostAppeals" => {},
    "PostApprovals" => {},
    "PostEvents" => {},
    "PostFlags" => {},
    "PostReplacements" => {},
    "PostVersions" => {},
    "PostVotes" => {},
    "RelatedTags" => {},
    "SavedSearches" => {},
    "Source" => {},
    "TagAliases" => {},
    "TagImplications" => {},
    "Tags" => { default_params: { "search[hide_empty]": "no", only: "id,name,post_count,wiki_page" } },
    "Uploads" => {},
    "Users" => {},
    "UserFeedback" => { url: "user_feedbacks" },
    "UserNameChangeRequests" => {},
    "UserRevert" => {},
    "WikiPages" => { default_params: { only: "id,title,body,tag" } },
    "WikiPageVersions" => {},
  }.freeze

  INCLUDE_MAP = {
    creator: "users",
    topic: "forum_posts",
  }.with_indifferent_access.freeze

  def initialize(url: ENV["BOORU_URL"], # rubocop:disable Style/FetchEnvVar
                 user: ENV["BOORU_USER"], # rubocop:disable Style/FetchEnvVar
                 api_key: ENV["BOORU_API_KEY"], # rubocop:disable Style/FetchEnvVar
                 factory: {},
                 log: Logger.new(nil))
    url ||= "https://danbooru.donmai.us"

    @url, @user, @api_key, @log = Addressable::URI.parse(url), user, api_key, log
    @http = Danbooru::HTTP.new(url, user: user, pass: api_key, log: log)
    @factory, @resources = factory.with_indifferent_access, {}
  end

  def ping(params = {})
    posts.ping(params)
  end

  def logged_in?
    return false unless user.present? && api_key.present?

    users.index(name: user).succeeded?
  end

  def [](name)
    name = name.to_s.camelize

    raise ArgumentError, "invalid resource name '#{name}'" unless RESOURCES.has_key?(name)

    resources[name] ||= Resource.const_get(name).new(name.underscore, self, **RESOURCES[name])
  end

  RESOURCES.keys.each do |name|
    Resource.const_set(name, Class.new(Resource)) unless Resource.const_defined?(name)

    define_method(name.underscore) do
      self[name]
    end
  end

  def self.map_attribute(attribute)
    INCLUDE_MAP[attribute]
  end
end
