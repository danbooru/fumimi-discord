require "dotenv"
Dotenv.load

require "fumimi/version"
require "fumimi/bq"
require "fumimi/comment"
require "fumimi/forum_post"
require "fumimi/post"
require "fumimi/tag"
require "fumimi/wiki_page"
require "danbooru/resource"

require "danbooru"

require "active_support"
require "active_support/core_ext"
require "bitly"
require "discordrb"
require "google/cloud/storage"
require "pg"
require "pry"
require "pry-byebug"

require "optparse"
require "shellwords"

module Fumimi::Events
  def do_post_id(event)
    post_ids = event.text.scan(/post #[0-9]+/i).grep(/([0-9]+)/) { $1.to_i }

    post_ids.each do |post_id|
      post = booru.posts.show(post_id)
      post.send_embed(event.channel)
    end

    nil
  end

  def do_forum_id(event)
    forum_post_ids = event.text.scan(/forum #[0-9]+/i).grep(/([0-9]+)/) { $1.to_i }

    forum_post_ids.each do |id|
      forum_post = booru.forum_posts.show(id)
      Fumimi::ForumPost.render_forum_posts(event.channel, [forum_post], booru)
    end

    nil
  end

  def do_wiki_link(event)
    event.channel.start_typing

    titles = event.text.scan(/\[\[ ( [^\]]+ ) \]\]/x).flatten
    titles.each do |title|
      Fumimi::WikiPage.render_wiki_page(event.channel, title, booru)
    end

    nil
  end

  def do_issue_id(event)
    issue_ids = event.text.scan(/issue #[0-9]+/i).grep(/([0-9]+)/) { $1.to_i }

    issue_ids.each do |issue_id|
      event.send_message "https://github.com/r888888888/danbooru/issues/#{issue_id}"
    end

    nil
  end

  def do_convert_post_links(event)
    event.message.content =~ %r!^https?://(?:danbooru|sonohara|hijiribe|safebooru)\.donmai\.us/posts/([0-9]+)(?:\?tags=.*)?$!
    post_id = $1.to_i

    event.message.delete

    post = booru.posts.show(post_id)
    post.send_embed(event.channel)

    nil
  end
end

module Fumimi::Commands
  class CommandArgumentError < StandardError; end

  def self.command(name, &block)
    define_method(:"do_#{name}") do |event, *args|
      begin
        message = event.send_message "*Please wait warmly until Fumimi is ready. This may take up to 60 seconds.*"
        event.channel.start_typing

        instance_exec(event, *args, &block)
      rescue CommandArgumentError => e
        event << "```#{e.to_s}```"
      rescue StandardError, RestClient::Exception => e
        event.drain
        event << "Exception: #{e.to_s}.\n"
        event << "https://i.imgur.com/0CsFWP3.png"
      ensure
        message.delete
        nil
      end
    end
  end

  def do_hi(event, *args)
    event.send_message "Command received. Deleting all animes."; sleep 1

    event.send_message "5..."; sleep 1
    event.send_message "4..."; sleep 1
    event.send_message "3..."; sleep 1
    event.send_message "2..."; sleep 1
    event.send_message "1..."; sleep 1

    event.send_message "Done! Animes deleted."
  end

  def do_say(event, *args)
    return unless event.user.id == 310167383912349697

    channel_name = args.shift
    message = args.join(" ")

    channels[channel_name].send_message(message)
  end

  def do_random(event, *tags)
    post = booru.posts.index(random: 1, limit: 1, tags: tags.join(" ")).first
    post.send_embed(event.channel)
    nil
  end

  def do_posts(event, *tags)
    limit = tags.grep(/limit:(\d+)/i) { $1.to_i }.first
    limit ||= 3 
    limit = [10, limit].min

    tags = tags.grep_v(/limit:(\d+)/i)
    posts = booru.posts.index(limit: limit, tags: tags.join(" "))

    posts.each do |post|
      post.send_embed(event.channel)
    end

    nil
  end

  command :mass_update do |event, *args|
    return unless event.user.id == 310167383912349697

    raise ArgumentError unless args.join(" ") =~ /^update (.*) -> (.*)$/
    search, tags = $1, $2

    n = 0
    progress_message = event.send("Updating `#{search}` with `#{tags}`...")

    booru.posts.each(tags: search).each do |post|
      if n % 20 == 0
        progress_message.edit("Updating `#{search}` with `#{tags}`... (post ##{post.id})")
      end

      post.update!("post[old_tag_string]": "", "post[tag_string]": tags)
      n += 1
    end

    progress_message.edit("Updated #{n} `#{search}` posts.")
  end

  command :count do |event, *tags|
    query = (tags + ["id:>-#{rand(2**32)}"]).join(" ").downcase
    resp = booru.counts.index(tags: query)

    event << "`#{tags.join(" ")}`: #{resp.counts["posts"]} posts"
  end

  def do_iqdb(event, *urls)
    url = urls.first or return

    event.channel.start_typing
    iqdb_queries = booru.iqdb_queries.index(url: url)

    iqdb_queries.map(&:post).each do |post|
      post.send_embed(event.channel)
    end

    nil
  end

  def do_forum(event, *args)
    event.channel.start_typing

    limit = args.grep(/limit:(\d+)/i) { $1.to_i }.first
    limit ||= 3 
    limit = [10, limit].min
    body = args.grep_v(/limit:(\d+)/i).join(" ")

    # XXX
    forum_posts = booru.forum_posts.search(body_matches: body).take(limit)
    Fumimi::ForumPost.render_forum_posts(event.channel, forum_posts, booru)

    nil
  end

  def do_comments(event, *tags)
    limit = tags.grep(/limit:(\d+)/i) { $1.to_i }.first
    limit ||= 3 
    limit = [10, limit].min
    tags = tags.grep_v(/limit:(\d+)/i)

    comments = booru.comments.search(post_tags_match: tags.join(" ")).take(limit)
    Fumimi::Comment.render_comments(event.channel, comments, booru)

    nil
  end

  command :sql do |event, *args|
    return unless event.user.id == 310167383912349697

    sql = args.join(" ")
    @pg = PG::Connection.open(dbname: "danbooru2")
    results = @pg.exec(sql)

    headers = results.fields
    rows = results.map(&:values)
    table = Terminal::Table.new do |t|
      t.headings = headers

      rows.each do |row|
        t << row
        break if t.to_s.size >= 1600
      end
    end

    event << "```"
    event << table.to_s.force_encoding("UTF-8")
    event << "#{table.rows.size} of #{results.ntuples} rows"
    event << "```"
  end

  def do_time(event, *args)
    # format: Thu, Nov 02 2017  6:11 PM CDT
    Time.use_zone("US/Pacific")    { event << "`US (west): #{Time.current.strftime("%a, %b %d %Y %l:%M %p %Z")}`" }
    Time.use_zone("US/Eastern")    { event << "`US (east): #{Time.current.strftime("%a, %b %d %Y %l:%M %p %Z")}`" }
    Time.use_zone("Europe/Berlin") { event << "`Europe:    #{Time.current.strftime("%a, %b %d %Y %l:%M %p %Z")}`" }
    Time.use_zone("Asia/Tokyo")    { event << "`Japan:     #{Time.current.strftime("%a, %b %d %Y %l:%M %p %Z")}`" }
  end

  def do_logs(event, *args)
    raise ArgumentError unless args.size == 1
    raise ArgumentError unless channels[args[0]].present?
    channel = channels[args[0]]

    loading_message = event.send_message "*Please wait warmly until Fumimi is ready.*"
    event.channel.start_typing

    output = Tempfile.new

    after_id = 0
    loop do
      messages = channel.history(100, nil, after_id).reverse
      break if messages.empty?

      after_id = messages.last.id
      loading_message.edit("Downloading messages (last seen: #{messages.last.timestamp.utc.strftime("%a, %b %d %Y %l:%M %p %Z")})...")

      logged_messages = messages.map do |message|
        {
          id: message.id,
          created_at: message.timestamp,
          updated_at: message.edited_timestamp,
          author: {
            id: message.author.id,
            username: message.author.username,
            discriminator: message.author.discriminator,
          },
          channel: {
            id: message.channel.id,
            name: message.channel.name,
          },
          content: message.content,
          embeds: message.embeds.map do |embed|
            {
              title: embed.title,
              url: embed.url,
              description: embed.description,
              author: {
                name: embed.author.try(:name),
                url: embed.author.try(:url),
              }
            }
          end
        }
      end

      logged_messages.map(&:to_json).each do |message|
        output.write(message + "\n")
      end
    end

    filename = "fumimi/discord/logs/#{server.name}/#{channel.name}/#{Time.current.to_i}.json"
    file = storage.bucket("evazion").create_file(output.path, filename, acl: "public")
    event << file.public_url

    output.close
    output.delete

    nil
  end

  command :top do |event, *args|
    if args.join(" ") !~ /^(reverted-tags|tags|taggers|uploaders|approvers) in last (day|week|month|year|century|millenium)$/i
      raise CommandArgumentError.new("Usage: /top <uploaders|approvers|taggers|tags> in last <day|week|month|year|century|millenium>")
    end

    period = case args[3]
      when "year"  then (1.year.ago..Time.current)
      when "month" then (1.month.ago..Time.current)
      when "week"  then (1.week.ago..Time.current)
      when "day"   then (1.day.ago..Time.current)
      else              (20.years.ago..Time.current)
    end

    if args[0] == "uploaders"
      event << bq.top_uploaders(period).resolve_user_ids!(booru).to_table("Top Uploaders in Last #{args[3].capitalize}")
    elsif args[0] == "approvers"
      event << bq.top_approvers(period).resolve_user_ids!(booru).to_table("Top Approvers in Last #{args[3].capitalize}")
    elsif args[0] == "taggers"
      event <<  bq.top_taggers(period).resolve_user_ids!(booru).to_table("Top Taggers in Last #{args[3].capitalize} (excluding tags on uploads)")
    elsif args[0] == "tags"
      cutoff = case args[3]
        when "day"   then 1.0
        when "week"  then 2.0
        when "month" then 3.0
        else 20.0
      end

      event << bq.top_tags(period, cutoff).to_table("Top Tags in Last #{args[3].capitalize} (cutoff: >#{cutoff}% net change)")
    elsif args[0] == "reverted-tags"
      event << bq.top_reverted_tags(period).to_table("Top Reverted Tags in Last #{args[3].capitalize}")
    end
  end

  command :bq do |event, *args|
    query = args.join(" ")
    event << bq.query(query).to_table
  end

  command :search do |event, *args|
    tags = args.join(" ")
    results = bq.search(booru, tags)

    results.take(1000).flat_map(&:values).in_groups_of(250, false).each_with_index do |post_ids, i|
      url = "https://danbooru.donmai.us/posts?tags=id:#{post_ids.join(",")}"
      short_url = bitly.shorten(url, domain: "j.mp").short_url

      first = (i*250 + 1).to_s
      last  = (i*250 + post_ids.size).to_s

      event << "`#{tags} | #{first} - #{last} of #{results.total} posts`: #{short_url}"
    end

    nil
  end

  command :user do |event, *args|
    raise ArgumentError unless args.present?

    username = args.join("_").downcase
    user_id = booru.users.search(name: username).first.try(:id) or raise ArgumentError, "invalid username"

    event << bq.top_tags_for_user(user_id).resolve_user_ids!(booru).to_table("Top Tags Used by #{username}")
  end

  command :tag do |event, *args|
    opts = {}
    argv = Shellwords.split(args.join(" "))

    parser = OptionParser.new do |parser|
      parser.banner = "Usage: /tag [--creator|--users|--growth|--reverts|--all] [--help] <tag>"
      parser.separator "Options:"

      parser.on("-c", "--creator", "Show creator of tag") { opts[:creator] = true }
      parser.on("-u", "--users", "Show top users of tag (default)") { opts[:users] = true }
      parser.on("-g", "--growth", "Show tag growth over time") { opts[:growth] = true }
      parser.on("-r", "--reverts", "Show most reverted posts for this tag") { opts[:reverts] = true }
      parser.on("-a", "--all", "Show all of the above") do
        opts[:creator] = opts[:users] = opts[:growth] = opts[:reverts] = true
      end
      parser.on("-h", "--help", "Print this help") { opts[:help] = true }
    end

    parser.parse!(argv)
    tag = argv.join("_").downcase
    opts[:users] = true if opts.empty?
    opts[:help] = true if tag.empty?

    if opts[:help]
      event << "```#{parser}```"
      next
    end

    if opts[:creator]
      results = bq.tag_creator(tag).resolve_user_ids!(booru)
      event.send_message(results.to_table("Creator of '#{tag}'"))
    end

    if opts[:users]
      results = bq.tag_usage_by_group(tag, "updater_id", "updater_id", "added + removed DESC").resolve_user_ids!(booru)
      event.send_message(results.to_table("'#{tag}' Usage By User"))
    end

    if opts[:growth]
      results = bq.tag_usage_by_group(tag, "EXTRACT(year FROM updated_at)", "year", "year ASC").resolve_user_ids!(booru)
      event.send_message(results.to_table("'#{tag}' Usage By Year"))
    end

    if opts[:reverts]
      results = bq.top_reverted_posts_for_tag(tag)
      event.send(results.to_table("Most reverted '#{tag}' posts"))
    end
  end

  command :stats do |event, *args|
    if args == %w[longest tags]
      query = "SELECT name FROM `tags` AS t WHERE t.count > 0 ORDER BY LENGTH(t.name) DESC LIMIT 20"
    elsif args.size == 4 && args[1..2] == %w[created by]
      username = args[3]
      user = booru.users.search(name: username).first

      case args[0]
      when "gentags" then categories = [0]
      when "arttags" then categories = [1]
      when "copytags" then categories = [3]
      when "chartags" then categories = [4]
      when "metatags" then categories = [5]
      when "tags" then categories = [0, 1, 3, 4, 5]
      else categories = [0, 1, 3, 4, 5]
      end

      event << bq.tags_created_by_user(user.id, categories).to_table("Tags Created By #{username}")
    else
      event << "Usage:\n"
      event << "`/stats longest tags`"
      event << "`/stats tags created by <username>`"
      event << "`/stats gentags created by <username>`"
      event << "`/stats arttags created by <username>`"
      event << "`/stats chartags created by <username>`"
      event << "`/stats copytags created by <username>`"
      event << "`/stats metatags created by <username>`"
    end
  end
end

class Fumimi
  include Fumimi::Commands
  include Fumimi::Events

  attr_reader :server_id, :client_id, :token, :log
  attr_reader :bot, :server, :bitly, :booru, :bq, :storage
  attr_reader :initiate_shutdown

  def initialize(server_id:, client_id:, token:, bitly_username:, bitly_api_key:, log: Logger.new(STDERR))
    @server_id = server_id
    @client_id = client_id
    @token = token
    @log = RestClient.log = log

    @booru = Danbooru.new(factory: { posts: Fumimi::Post, tags: Fumimi::Tag, comments: Fumimi::Comment, forum_posts: Fumimi::ForumPost, wiki_pages: Fumimi::WikiPage })
    @bq = Fumimi::BQ.new(project: "danbooru-1343", dataset: "danbooru_production")
    @storage = Google::Cloud::Storage.new
    @bitly = Bitly.new(bitly_username, bitly_api_key)
  end

  def server
    bot.servers.fetch(@server_id)
  end

  def channels
    server.channels.group_by(&:name).transform_values(&:first)
  end

  def shutdown!
    log.info("Shutting down...")
    bot.stop
    exit(0)
  end

  def register_commands
    log.debug("Registering bot commands...")

    bot.message(contains: /post #[0-9]+/i, &method(:do_post_id))
    bot.message(contains: /forum #[0-9]+/i, &method(:do_forum_id))
    bot.message(contains: /issue #[0-9]+/i, &method(:do_issue_id))
    bot.message(contains: /\[\[ [^\]]+ \]\]/x, &method(:do_wiki_link))
    bot.message(contains: %r!^https?://(?:danbooru|sonohara|hijiribe|safebooru)\.donmai\.us/posts/([0-9]+)(?:\?tags=.*)?$!, &method(:do_convert_post_links))
    bot.command(:hi, description: "Say hi to Fumimi: `/hi`", &method(:do_hi))
    bot.command(:posts, description: "List posts: `/posts <tags>`", &method(:do_posts))
    bot.command(:mass, description: "Update posts: `/mass update <search> -> <tags>`", &method(:do_mass_update))
    bot.command(:count, description: "Count posts: `/count <tags>`", &method(:do_count))
    bot.command(:iqdb, description: "Find similar posts: `/iqdb <url>`", &method(:do_iqdb))
    bot.command(:comments, description: "List comments: `/comments <tags>`", &method(:do_comments))
    bot.command(:forum, description: "List forum posts: `/forum <text>`", &method(:do_forum))
    bot.command(:random, description: "Show a random post: `/random <tags>`", &method(:do_random))
    bot.command(:stats, description: "Query various stats: `/stats help`", &method(:do_stats))
    bot.command(:tag, description: "Show tag information: `/tag <name>`", &method(:do_tag))
    bot.command(:user, description: "Show information about user: `/user <name>`", &method(:do_user))
    bot.command(:search, description: "Search posts on BigQuery: `/search <tags>`", &method(:do_search))
    bot.command(:bq, description: "Run a query on BigQuery: `/bq <query>`", &method(:do_bq))
    bot.command(:top, description: "Show leaderboards: `/top <uploaders|approvers|taggers|tags> in last <day|week|month|year>`", &method(:do_top))
    bot.command(:time, description: "Show current time in various time zones across the world", &method(:do_time))
    bot.command(:logs, description: "Dump channel log in JSON format: `/logs <channel-name>`", &method(:do_logs))
    bot.command(:sql, help_available: false, &method(:do_sql))
    bot.command(:say, help_available: false, &method(:do_say))
  end

  def run_commands
    log.debug("Starting bot...")

    @bot = Discordrb::Commands::CommandBot.new({
      name: "Robot Maid Fumimi",
      client_id: client_id,
      token: token,
      prefix: '/',
    })

    register_commands
    bot.run(:async)

    loop do
      shutdown! if initiate_shutdown
      sleep 1
    end
  end

  def run_feeds(comment_feed: "", upload_feed: "", forum_feed: "", error_channel: "")
    log.debug("Entering feed update loop...")

    @bot = Discordrb::Bot.new({
      name: "Robot Maid Fumimi",
      client_id: client_id,
      token: token,
    })

    bot.run(:async)

    last_upload_time = Time.now
    last_comment_time = Time.now
    last_forum_post_time = Time.now

    loop do
      last_upload_time = update_uploads_feed(last_upload_time, channels[upload_feed])
      last_comment_time = update_comments_feed(last_comment_time, channels[comment_feed])
      last_forum_post_time = update_forum_feed(last_forum_post_time, channels[forum_feed])

      sleep 30
    end
  rescue StandardError => e
    msg =  "Error. Retrying in 60s...\n\n"
    msg += "Exception: #{e.to_s}.\n"
    msg += "https://i.imgur.com/0CsFWP3.png"

    bot.send_message(channels[error_channel], msg)

    sleep 60
    retry
  end

  def update_uploads_feed(last_checked_at, channel)
    log.debug("Checking /posts (last seen: #{last_checked_at}).")

    posts = booru.posts.newest(last_checked_at, 50).reverse

    posts.each do |post|
      post.send_embed(channel)
    end

    posts.last&.created_at || last_checked_at
  end

  def update_comments_feed(last_checked_at, channel)
    log.debug("Checking /comments (last seen: #{last_checked_at}).")

    comments = booru.comments.newest(last_checked_at, 50).reverse
    comments = comments.reject(&:do_not_bump_post)
    Fumimi::Comment.render_comments(channel, comments, booru)

    comments.last&.created_at || last_checked_at
  end

  def update_forum_feed(last_checked_at, channel)
    log.debug("Checking /forum_posts (last seen: #{last_checked_at}).")

    forum_posts = booru.forum_posts.newest(last_checked_at, 50).reverse
    Fumimi::ForumPost.render_forum_posts(channel, forum_posts, booru)

    forum_posts.last&.created_at || last_checked_at
  end

  def initiate_shutdown!
    @initiate_shutdown = true
  end
end
