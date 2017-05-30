require "rest-client"

require "danbooru/resource"
require "danbooru/comment"
require "danbooru/forum_post"
require "danbooru/post"
require "danbooru/tag"
require "danbooru/wiki"
require "danbooru/iqdb_query"
require "danbooru/pool"

class Danbooru
  attr_reader :host, :user, :api_key, :site
  attr_reader :posts, :users, :comments, :forum_posts, :wiki, :tags, :bans, :iqdb, :pools

  def initialize(host: ENV["BOORU_HOST"], user: ENV["BOORU_USER"], api_key: ENV["BOORU_API_KEY"])
    @host, @user, @api_key = host, user, api_key

    @site = Danbooru::Resource.new(@host, {
      user: user,
      password: api_key,
      headers: { accept: :json },
    })

    @posts = @site["/posts"]
    @users = @site["/users"]
    @comments = @site["/comments"].with(group_by: :comment)
    @forum_posts = @site["/forum_posts"]
    @wiki = @site["/wiki_pages"]
    @tags = @site["/tags"]
    @bans = @site["/bans"]
    @iqdb = @site["/iqdb_queries"]
    @pools = @site["/pools"]

    posts.factory = Danbooru::Post
    comments.factory = Danbooru::Comment
    forum_posts.factory = Danbooru::ForumPost
    tags.factory = Danbooru::Tag
    wiki.factory = Danbooru::Wiki
    iqdb.factory = Danbooru::IqdbQuery
    pools.factory = Danbooru::Pool
  end
end
