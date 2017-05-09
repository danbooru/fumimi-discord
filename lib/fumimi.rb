require "fumimi/version"
require "danbooru/model"
require "danbooru/resource"

require "active_support"
require "active_support/core_ext/hash/indifferent_access"
require "active_support/core_ext/object/to_query"
require "active_support/core_ext/object/blank"
require "active_support/core_ext/numeric/conversions"
require "discordrb"
require "dotenv"
require "pry"
require "pry-byebug"

require "dtext"
require "nokogiri"

Dotenv.load

class Danbooru
  module HasDText
    def html_body
      DTextRagel.parse(body)
    end

    def pretty_body
      nodes = Nokogiri::HTML.fragment(html_body)

      nodes.children.map do |node|
        case node.name
        when "i"
          "*#{node.text.gsub(/\*/, "\*")}*"
        when "b"
          "**#{node.text.gsub(/\*\*/, "\*\*")}**"
        when "div", "blockquote"
          # no-op
          nil
        else
          node.text
        end
      end.compact.take(2).join("\n\n")
    end
  end
end

class Danbooru
  class Post < Danbooru::Model
    def url
      "https://danbooru.donmai.us/posts/#{id}"
    end

    def full_large_file_url
      if has_large
        "https://danbooru.donmai.us#{large_file_url}"
      else
        full_preview_file_url
      end
    end

    def full_preview_file_url
      "https://danbooru.donmai.us#{preview_file_url}"
    end

    def shortlink
      "post ##{id}"
    end

    def embed_thumbnail(channel_name)
      if is_censored? || is_unsafe?(channel_name)
        Discordrb::Webhooks::EmbedThumbnail.new(url: "http://danbooru.donmai.us.rsz.io#{preview_file_url}?blur=30")
      else
        Discordrb::Webhooks::EmbedThumbnail.new(url: full_preview_file_url)
      end
    end

    def embed_image(channel_name)
      if is_censored? || is_unsafe?(channel_name)
        Discordrb::Webhooks::EmbedImage.new(url: "http://danbooru.donmai.us.rsz.io#{large_file_url}?blur=30")
      else
        Discordrb::Webhooks::EmbedImage.new(url: full_large_file_url)
      end
    end

    def is_unsafe?(channel_name)
      nsfw_channel = (channel_name =~ /^nsfw/i)
      rating != "s" && !nsfw_channel
    end

    def is_censored?
      tag_string.split.grep(/^(loli|shota|toddlercon|guro|scat)$/).any?
    end

    def border_color
      if is_flagged
        0xC41C19
      elsif parent_id
        0x00FF00
      elsif has_active_children
        0xC0C000
      elsif is_pending
        0x0000FF
      end
    end

    def embed_footer
      file_info = "#{image_width}x#{image_height} (#{file_size.to_s(:human_size, precision: 4)} #{file_ext})"
      timestamp = "#{created_at.strftime("%F")} at #{created_at.strftime("%l:%M %p")}"

      Discordrb::Webhooks::EmbedFooter.new({
        text: "#{file_info} | #{timestamp}"
      })
    end
  end
end

class Danbooru
  class Comment < Danbooru::Model
    include HasDText

    def embed_footer
      timestamp = "#{created_at.strftime("%F")} at #{created_at.strftime("%l:%M %p")}"
      Discordrb::Webhooks::EmbedFooter.new(text: timestamp)
    end
  end
end

class Danbooru
  class Tag < Danbooru::Model
    def example_post(booru)
      case category
      when 0
        search = "#{name} rating:safe order:score filetype:jpg limit:1"
      when 1 # artist
        search = "#{name} rating:safe order:score filetype:jpg limit:1"
      when 3 # copy
        search = "#{name} everyone rating:safe order:score filetype:jpg limit:1"
      when 4 # char
        search = "#{name} chartags:1 rating:safe order:score filetype:jpg limit:1"
      end

      post = booru.posts.index(tags: search).first
      post
    end
  end
end

class Danbooru
  class Wiki < Danbooru::Model
    include Danbooru::HasDText
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

    posts.factory = Danbooru::Post
    comments.factory = Danbooru::Comment
    tags.factory = Danbooru::Tag
    wiki.factory = Danbooru::Wiki
  end
end

class Fumimi
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

    bot.command(:random, usage: "/random <tags>", description: "Show a random post") do |event, *tags|
      "https://danbooru.donmai.us/posts/random?tags=#{tags.join("%20")}"
    end

    bot.command(:hi, description: "Say hi to Fumimi!") do |event, *args|
      event.send_message "Command received. Deleting all animes."; sleep 1

      event.send_message "5..."; sleep 1
      event.send_message "4..."; sleep 1
      event.send_message "3..."; sleep 1
      event.send_message "2..."; sleep 1
      event.send_message "1..."; sleep 1

      event.send_message "Done! Animes deleted."
    end

    bot.message(contains: /post #[0-9]+/) do |event|
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

    bot.message(contains: /\[\[ [^\]]+ \]\]/x) do |event|
      titles = event.text.scan(/\[\[ ( [^\]]+ ) \]\]/x).flatten

      titles.each do |title|
        render_wiki(event, title.tr(" ", "_"))
      end
    end

    bot.command(:posts, usage: "/posts <tags>", description: "Search for posts on Danbooru") do |event, *tags|
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

    bot.command(:comments, usage: "/comments <tags>", description: "List the latest comments") do |event, *tags|
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

=begin
    @bot.command(:forum, usage: "/forum <search>", description: "List the latest forum posts") do |event, *args|
      body = args.join(" ")
      resp = RestClient.get("http://danbooru.donmai.us/forum_posts?search[body_matches]=#{body}&limit=5", {accept: :json})
      posts = JSON.parse(resp.body)
      posts = posts.take(5)

      creator_ids = posts.map { |p| p["creator_id"] }
      resp = RestClient.get("http://danbooru.donmai.us/users.json?search[id]=#{creator_ids.join(",")}")
      users = JSON.parse(resp.body).group_by { |u| u["id"] }

      event.send_message("Newest forum posts:")
      posts.each do |p|
        event.channel.send_embed do |embed|
          embed.title = "topic ##{p["topic_id"]}: forum ##{p["id"]}"
          embed.url = "https://danbooru.donmai.us/forum_posts/#{p["id"]}"

          username = users[p["creator_id"]].first["name"]
          embed.author = Discordrb::Webhooks::EmbedAuthor.new(name: "@#{username}", url: "https://danbooru.donmai.us/users/#{p["creator_id"]}")
          embed.description = p["body"].gsub(/\[quote\].*\[\/quote\]/mi, "")
        end
      end
      nil
    end

    bot.member_join do |event, *args|
      thing = %w[post pool tag character copyright artist].sample
      event.respond("*Fumimi would like to know your favorite #{thing}.*")
    end
=end
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
