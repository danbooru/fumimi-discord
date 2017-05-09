require "fumimi/version"
require "danbooru/resource"

require "danbooru"
require "danbooru/model"
require "danbooru/comment"
require "danbooru/post"
require "danbooru/tag"
require "danbooru/wiki"

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

module Fumimi::Events
  def do_post_id(event)
    post_ids = event.text.scan(/post #[0-9]+/i).grep(/([0-9]+)/) { $1.to_i }

    post_ids.each do |post_id|
      post = booru.posts.show(post_id)
      # tags = booru.tags.with(limit: 1000).search(name: post.tag_string.split.join(","))

      event.channel.send_embed do |embed|
        embed_post(embed, event.channel.name, post)
      end
    end

    nil
  end

  def do_wiki_link(event)
    titles = event.text.scan(/\[\[ ( [^\]]+ ) \]\]/x).flatten

    titles.each do |title|
      render_wiki(event, title.tr(" ", "_"))
    end
  end
end

module Fumimi::Commands
  def do_hi(event, *args)
    event.send_message "Command received. Deleting all animes."; sleep 1

    event.send_message "5..."; sleep 1
    event.send_message "4..."; sleep 1
    event.send_message "3..."; sleep 1
    event.send_message "2..."; sleep 1
    event.send_message "1..."; sleep 1

    event.send_message "Done! Animes deleted."
  end

  def do_random(event, *args)
    "https://danbooru.donmai.us/posts/random?tags=#{tags.join("%20")}"
  end

  def do_posts(event, *tags)
    limit = tags.grep(/limit:(\d+)/i) { $1.to_i }.first
    limit ||= 3 
    limit = [10, limit].min

    tags = tags.grep_v(/limit:(\d+)/i)
    posts = booru.posts.index(limit: limit, tags: tags.join(" "))

    posts.each do |post|
      event.channel.send_embed do |embed|
        embed_post(embed, event.channel.name, post)
      end
    end

    nil
  end

  def do_forum(event, *args)
    limit = args.grep(/limit:(\d+)/i) { $1.to_i }.first
    limit ||= 3 
    limit = [10, limit].min
    body = args.grep_v(/limit:(\d+)/i).join(" ")

    forum_posts = booru.forum_posts.with(limit: limit).search(body_matches: body)

    creator_ids = forum_posts.map(&:creator_id).join(",")
    users = booru.users.search(id: creator_ids).group_by(&:id).transform_values(&:first)

    #topic_ids = forum_posts.map(&:topic_id).join(",")
    #forum_topics = booru.forum_topics.search(id: topic_ids).group_by(&:id).transform_values(&:first)
    forum_topics = nil

    forum_posts.each do |forum_post|
      event.channel.send_embed do |embed|
        embed_forum_post(embed, forum_post, forum_topics, users)
      end
    end

    nil
  end

  def do_comments(event, *tags)
    limit = tags.grep(/limit:(\d+)/i) { $1.to_i }.first
    limit ||= 3 
    limit = [10, limit].min
    tags = tags.grep_v(/limit:(\d+)/i)

    comments = booru.comments.with(limit: limit).search(post_tags_match: tags.join(" "))

    creator_ids = comments.map(&:creator_id).join(",")
    users = booru.users.search(id: creator_ids).group_by(&:id).transform_values(&:first)

    post_ids = comments.map(&:post_id).join(",")
    posts = booru.posts.with(tags: "id:#{post_ids}").search.group_by(&:id).transform_values(&:first)

    comments.each do |comment|
      event.channel.send_embed do |embed|
        embed_comment(embed, event.channel.name, comment, users, posts)
      end
    end

    nil
  end
end

class Fumimi
  include Fumimi::Commands
  include Fumimi::Events

  attr_reader :bot, :server, :booru, :log

  def initialize(server_id:, client_id:, token:, log: Logger.new(STDERR))
    @server_id = server_id
    @log = RestClient.log = log

    @bot = Discordrb::Commands::CommandBot.new({
      name: "Robot Maid Fumimi",
      client_id: client_id,
      token: token,
      prefix: '/',
    })

    @booru = Danbooru.new
  end

  def server
    bot.servers.fetch(@server_id)
  end

  def channels
    server.channels.group_by(&:name).transform_values(&:first)
  end

  def shutdown!
    # log.info("Shutting down...")
    STDERR.puts "Shutting down..."
    exit(0)
  end

  def register_commands
    log.debug("Registering bot commands...")

    bot.message(contains: /post #[0-9]+/, &method(:do_post_id))
    bot.message(contains: /\[\[ [^\]]+ \]\]/x, &method(:do_wiki_link))

    bot.command(:hi, description: "Say hi to Fumimi: `/hi`", &method(:do_hi))
    bot.command(:posts, description: "List posts: `/posts <tags>`", &method(:do_posts))
    bot.command(:comments, description: "List comments: `/comments <tags>`", &method(:do_comments))
    bot.command(:forum, description: "List forum posts: `/forum <text>`", &method(:do_forum))
    bot.command(:random, description: "Show a random post: `/random <tags>`", &method(:do_random))
  end

  def embed_post(embed, channel_name, post, tags = nil)
    embed.author = Discordrb::Webhooks::EmbedAuthor.new({
      name: "post ##{post.id}",
      url: post.url,
    })

    embed.title = "@#{post.uploader_name}"
    embed.url = "https://danbooru.donmai.us/users?name=#{CGI::escape(post.uploader_name)}"
    embed.image = post.embed_image(channel_name)
    embed.color = post.border_color

    embed.footer = post.embed_footer

    embed

=begin
    chartags = tags.select { |t| t.category == 4 }.sort_by(&:post_count).reverse.take(1).map do |tag|
      p = tag.name.tr("_", " ").gsub(/\]/, "\]")
      t = CGI::escape(tag.name)
      "[#{p}](https://danbooru.donmai.us/posts?tags=#{t})"
    end.join(", ")

    copytags = tags.select { |t| t.category == 3 }.sort_by(&:post_count).reverse.take(1).map do |tag|
      p = tag.name.tr("_", " ").gsub(/\]/, "\]")
      t = CGI::escape(tag.name)
      "[#{p}](https://danbooru.donmai.us/posts?tags=#{t})"
    end.join(", ")

    arttags = tags.select { |t| t.category == 1 }.sort_by(&:post_count).reverse.take(1).map do |tag|
      p = tag.name.tr("_", " ").gsub(/\]/, "\]")
      t = CGI::escape(tag.name)
      "[#{p}](https://danbooru.donmai.us/posts?tags=#{t})"
    end.join(", ")

    gentags = tags.select { |t| t.category == 0 }.sort_by(&:post_count).take(10).map do |tag|
      p = tag.name.tr("_", " ").tr("]", "\]")
      t = CGI::escape(tag.name)
      "[#{p}](https://danbooru.donmai.us/posts?tags=#{t})"
    end.join(", ")
=end
  end

  def embed_comment(embed, channel_name, comment, users, posts)
    user = users[comment.creator_id]
    post = posts[comment.post_id]

    embed.title = "@#{user.name}"
    embed.url = "https://danbooru.donmai.us/users?name=#{user.name}"

    embed.author = Discordrb::Webhooks::EmbedAuthor.new({
      name: post.shortlink,
      url: post.url,
    })

    embed.description = comment.pretty_body

    #embed.image = post.embed_image(event)
    embed.thumbnail = post.embed_thumbnail(channel_name)
    embed.footer = comment.embed_footer
  end

  def embed_forum_post(embed, forum_post, forum_topics, users)
    user = users[forum_post.creator_id]
    # topic = forum_topics[forum_post.topic_id]

    embed.author = Discordrb::Webhooks::EmbedAuthor.new({
      # name: topic.title,
      name: "forum ##{forum_post.id}",
      url: "https://danbooru.donmai.us/forum_posts/#{forum_post.id}"
    })

    embed.title = "@#{user.name}"
    embed.url = "https://danbooru.donmai.us/users?name=#{user.name}"

    embed.description = forum_post.body
  end

  def render_wiki(event, title)
    wiki = booru.wiki.show(title)
    tag  = booru.tags.search(name: title).first
    post = tag.example_post(booru)

    event.channel.send_embed do |embed|
      embed.author = Discordrb::Webhooks::EmbedAuthor.new({
        name: title.tr("_", " "),
        url: "https://danbooru.donmai.us/wiki_pages/#{title}"
      })

      embed.description = wiki.pretty_body
      embed.image = post.embed_image(event)
    end
  end

  def start
    log.debug("Starting bot...")

    register_commands
    bot.run(:async)
  end

  def update_feeds(comment_feed: "", upload_feed: "")
    log.debug("Entering feed update loop...")

    loop do
      last_checked_at = Time.now
      sleep 10

      #notify_new_uploads(last_checked_at)
      update_comments_feed(last_checked_at, channels[comment_feed])
      #notify_new_forum_posts(last_checked_at)
    end
  end

  def notify_new_uploads(last_checked_at)
    log.debug("Checking /posts (#{last_checked_at}).")
    posts = booru.posts.newest(last_checked_at, 50)

    channel = channels["upload-feed"]
    posts.each do |post|
      channel.send_embed do |embed|
        embed_post(embed, channel.name, post)
      end
    end
  end

  def update_comments_feed(last_checked_at, channel)
    log.debug("Checking /comments (#{last_checked_at}).")

    comments = booru.comments.newest(last_checked_at, 50)
    comments = comments.reject(&:do_not_bump_post)

    creator_ids = comments.map(&:creator_id).join(",")
    users = booru.users.search(id: creator_ids).group_by(&:id).transform_values(&:first)

    post_ids = comments.map(&:post_id).join(",")
    posts = booru.posts.with(tags: "id:#{post_ids}").search.group_by(&:id).transform_values(&:first)

    comments.each do |comment|
      channel.send_embed do |embed|
        embed_comment(embed, channel.name, comment, users, posts)
      end
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
