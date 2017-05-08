require "fumimi/version"

require "active_support"
require "active_support/core_ext/hash/indifferent_access"
require "active_support/core_ext/object/to_query"
require "active_support/core_ext/object/blank"
require "active_support/core_ext/numeric/conversions"
require "addressable/uri"
require "discordrb"
require "dotenv"
require "pry"
require "pry-byebug"

require "dtext"
require "nokogiri"

Dotenv.load

class Danbooru
  class Resource < RestClient::Resource
    attr_accessor :type

    def type
      @type ||= OpenStruct
    end

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

      array = JSON.parse(resp.body)
      array.map { |hash| deserialize(hash) }
    end

    def show(id)
      resp = self[id].get
      hash = JSON.parse(resp.body)
      deserialize(hash)
    end

    def newest(since, limit = 50)
      items = index(limit: limit)
      items.select { |i| i.created_at >= since }
    end

    def deserialize(hash)
      hash = hash.map do |key, value|
        value =
          case key
          when "created_at", "updated_at", "last_commented_at", "last_comment_bumped_at", "last_noted_at"
            Time.parse(value) rescue nil
          when /_url$/
            Addressable::URI.parse(value)
          else
            value
          end
        [key, value]
      end.to_h

      type.new(hash)
    end
  end
end

class Danbooru
  class Post < OpenStruct
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
      "https://danbooru.donmai.us#{large_file_url}"
    end

    def shortlink
      "post ##{id}"
    end

    def embed_thumbnail(event)
      if is_censored? || is_unsafe?(event)
        Discordrb::Webhooks::EmbedThumbnail.new(url: "http://danbooru.donmai.us.rsz.io#{preview_file_url}?blur=30")
      else
        Discordrb::Webhooks::EmbedThumbnail.new(url: full_preview_file_url)
      end
    end

    def embed_image(event)
      if is_censored? || is_unsafe?(event)
        Discordrb::Webhooks::EmbedImage.new(url: "http://danbooru.donmai.us.rsz.io#{large_file_url}?blur=30")
      else
        Discordrb::Webhooks::EmbedImage.new(url: full_large_file_url)
      end
    end

    def is_unsafe?(event)
      nsfw_channel = (event.channel.name =~ /^nsfw/i)
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
  class Comment < OpenStruct
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

    def embed_footer
      timestamp = "#{created_at.strftime("%F")} at #{created_at.strftime("%l:%M %p")}"
      Discordrb::Webhooks::EmbedFooter.new(text: timestamp)
    end
  end
end

class Danbooru
  class Tag < OpenStruct
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

    posts.type = Danbooru::Post
    comments.type = Danbooru::Comment
    tags.type = Danbooru::Tag
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

  def server
    bot.servers.values.first
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
        tags = booru.tags.with(limit: 1000).search(name: post.tag_string.split.join(","))

        event.channel.send_embed do |embed|
          embed_post(embed, event, post, tags)
        end
      end

      nil
    end

    bot.message(contains: /\[\[ [^\]]+ \]\]/x) do |event|
      titles = event.text.scan(/\[\[ ( [^\]]+ ) \]\]/x).flatten

      titles.each do |title|
        render_wiki(event, title)
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
          embed_post(embed, event, post, tags)
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
          embed_comment(embed, event, comment, users, posts)
        end
      end

      nil
    end

  def embed_post(embed, event, post, tags)
    embed.author = Discordrb::Webhooks::EmbedAuthor.new({
      name: "post ##{post.id}",
      url: post.url,
    })

    embed.title = "@#{post.uploader_name}"
    embed.url = "https://danbooru.donmai.us/users?name=#{post.uploader_name}"
    embed.image = post.embed_image(event)
    embed.color = post.border_color

    embed.footer = post.embed_footer

    embed
  end

  def embed_comment(embed, event, comment, users, posts)
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
    embed.thumbnail = post.embed_thumbnail(event)
    embed.footer = comment.embed_footer
  end

  def render_wiki(event, title)
    wiki = booru.wiki.show(title)
    tag  = booru.tags.search(name: title).first
    post = tag.example_post(booru)

    event.channel.send_embed do |embed|
      embed.title = title.tr("_", " ")
      embed.url = "https://danbooru.donmai.us/wiki_pages/#{wiki.title}"

      # embed.author = Discordrb::Webhooks::EmbedAuthor.new(name: "@#{wiki.creator_name}", url: "https://danbooru.donmai.us/users/#{wiki.creator_name}")

      embed.description = wiki.body
      embed.image = post.embed_image(event)
    end
  end

  def run
    log.debug("Running bot...")

    bot.run(:async)
    event_loop
    bot.sync
  end

  def event_loop
    loop do
      last_checked_at = Time.now
      sleep 20

      notify_new_uploads(last_checked_at)
      notify_new_comments(last_checked_at)
      notify_new_forum_posts(last_checked_at)
    end
  end

  def notify_new_uploads(last_checked_at)
    log.debug("Checking /posts (#{last_checked_at}).")
    posts = booru.posts.newest(last_checked_at, 50)

    posts.each do |post|
      channels["testing"].send_message(post.url)
    end
  end

  def notify_new_comments(last_checked_at)
    log.debug("Checking /comments (#{last_checked_at}).")
    comments = booru.comments.newest(last_checked_at, 50)

    comments.each do |comment|
      channels["testing"].send_message("https://danbooru.donmai.us/comments/#{comment.id}")
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
