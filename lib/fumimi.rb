require "dotenv"
Dotenv.load

class Fumimi; end
Dir[__dir__ + "/**/*.rb"].each { |file| require file }

require "danbooru"

require "active_support"
require "active_support/core_ext"
require "dentaku"
require "discordrb"
require "pry"
require "pry-byebug"
require "open-uri"
require "addressable/uri"

require "optparse"
require "shellwords"

module Fumimi::Events
  extend ActiveSupport::Concern

  def self.respond(name, regex, &block)
    @@messages ||= []
    @@messages << [{name: name, regex: regex}]

    define_method(:"do_#{name}") do |event, *args|
      matches = event.text.scan(/(?<!`)#{regex}(?!`)/)

      matches.each do |match|
        instance_exec(event, match, &block)
      end

      nil
    end
  end

  respond(:post_id, /post #[0-9]+/i) do |event, text|
    post_id = text[/[0-9]+/].to_i

    post = booru.posts.show(post_id)
    post.send_embed(event.channel)
  end

  respond(:forum_id, /forum #[0-9]+/i) do |event, text|
    forum_post_id = text[/[0-9]+/].to_i

    forum_post = booru.forum_posts.show(forum_post_id)
    Fumimi::Model::ForumPost.render_forum_posts(event.channel, [forum_post], booru)
  end

  respond(:topic_id, /topic #[0-9]+/i) do |event, text|
    topic_id = text[/[0-9]+/]

    forum_post = booru.forum_posts.search(topic_id: topic_id).to_a.last
    Fumimi::Model::ForumPost.render_forum_posts(event.channel, [forum_post], booru)
  end

  respond(:comment_id, /comment #[0-9]+/i) do |event, text|
    id = text[/[0-9]+/]

    comment = booru.comments.show(id)
    Fumimi::Model::Comment.render_comments(event.channel, [comment], booru)
  end

  respond(:wiki_link, /\[\[ [^\]]+ \]\]/x) do |event, text|
    title = text[/[^\[\]]+/]

    event.channel.start_typing
    Fumimi::Model::WikiPage.render_wiki_page(event.channel, title, booru)
  end

  respond(:search_link, /{{ [^\}]+ }}/x) do |event, text|
    search = text[/[^{}]+/]

    event.channel.start_typing
    posts = booru.posts.index(limit: 3, tags: search)

    posts.each do |post|
      post.send_embed(event.channel)
    end
  end

  respond(:artist_id, /artist #[0-9]+/i) do |event, text|
    id = text[/[0-9]+/]
    event << "https://danbooru.donmai.us/artists/#{id}"
  end

  respond(:note_id, /note #[0-9]+/i) do |event, text|
    id = text[/[0-9]+/]

    note = booru.notes.show(id)
    event << "https://danbooru.donmai.us/posts/#{note.post_id}#note-#{note.id}"
  end

  respond(:pixiv_id, /pixiv #[0-9]+/i) do |event, text|
    id = text[/[0-9]+/]
    event << "https://www.pixiv.net/member_illust.php?mode=medium&illust_id=#{id}"
  end

  respond(:pool_id, /pool #[0-9]+/i) do |event, text|
    id = text[/[0-9]+/]
    event << "https://danbooru.donmai.us/pools/#{id}"
  end

  respond(:user_id, /user #[0-9]+/i) do |event, text|
    id = text[/[0-9]+/]
    event << "https://danbooru.donmai.us/users/#{id}"
  end

  respond(:issue_id, /issue #[0-9]+/i) do |event, text|
    issue_id = text[/[0-9]+/]
    event.send_message "https://github.com/danbooru/danbooru/issues/#{issue_id}"
  end

  respond(:pull_id, /pull #[0-9]+/i) do |event, text|
    pull_id = text[/[0-9]+/]
    event.send_message "https://github.com/danbooru/danbooru/pull/#{pull_id}"
  end

  def do_convert_post_links(event)
    post_ids = []

    message = event.message.content.gsub(%r{\b(?!https?://\w+\.donmai\.us/posts/\d+/\w+)https?://(?!testbooru)\w+\.donmai\.us/posts/(\d+)\b[^[:space:]]*}i) do |link|
      post_ids << $1.to_i
      "<#{link}>"
    end

    if post_ids.present?
      event.message.delete
      event.send_message("#{event.author.display_name} posted: #{message}", false, nil, nil, false) # tts, embed, attachments, allowed_mentions

      post_ids.each do |post_id|
        post = booru.posts.show(post_id)
        post.send_embed(event.channel)
      end
    end

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
    return unless event.user.id == 310167383912349697 || event.user.id == 326364297561243649

    channel_name = args.shift
    message = args.join(" ")

    channels[channel_name].send_message(message)
  end

  command :calc do |event, *args|
    args = args.join(" ")

    result = Dentaku::Calculator.new.evaluate(args)
    event << "`#{args} = #{result}`"
  end

  command :ruby do |event, *args|
    return unless event.user.id == 310167383912349697

    code = args.join(" ")
    result = instance_eval(code)
    event << "`#{result.inspect}`"
  end

  def do_forum(event, *args)
    event.channel.start_typing

    limit = args.grep(/limit:(\d+)/i) { $1.to_i }.first
    limit ||= 3
    limit = [10, limit].min
    body = args.grep_v(/limit:(\d+)/i).join(" ")

    forum_posts = booru.forum_posts.index("search[body_matches]": body, limit: limit)
    Fumimi::Model::ForumPost.render_forum_posts(event.channel, forum_posts, booru)

    nil
  end

  def do_comments(event, *tags)
    limit = tags.grep(/limit:(\d+)/i) { $1.to_i }.first
    limit ||= 3
    limit = [10, limit].min
    tags = tags.grep_v(/limit:(\d+)/i)

    comments = booru.comments.index("search[post_tags_match]": tags.join(" "), limit: limit)
    Fumimi::Model::Comment.render_comments(event.channel, comments, booru)

    nil
  end

  def do_logs(event, *args)
    name = args.first
    raise ArgumentError unless name.present?

    if name[0] == "+"
      raise ArgumentError unless event.user.id == 310167383912349697

      username = name[1..-1]
      id, user = bot.users.find do |id, user|
        user.username == username
      end

      channel = user.pm
    else
      raise ArgumentError unless channels[name].present? && name.in?(%w[general nsfw offtopic tagging translations technical fumimi])

      channel = channels[name]
    end

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

    output.close
    filename = "fumimi/discord/logs/#{server.name}/#{channel.name}/#{Time.current.to_i}.json"
    file = storage.bucket("evazion").create_file(output.path, filename, acl: "public")
    event << file.public_url

    output.delete

    nil
  end
end

class Fumimi
  include Fumimi::Commands
  include Fumimi::Events

  attr_reader :server_id, :client_id, :token, :log
  attr_reader :bot, :server, :booru, :storage
  attr_reader :initiate_shutdown

  def initialize(server_id:, client_id:, token:, log: Logger.new(STDERR))
    @server_id = server_id
    @client_id = client_id
    @token = token
    @log = log

    factory = {
      posts: Fumimi::Model::Post,
      tags: Fumimi::Model::Tag,
      comments: Fumimi::Model::Comment,
      forum_posts: Fumimi::Model::ForumPost,
      wiki_pages: Fumimi::Model::WikiPage,
    }

    @booru = Danbooru.new(factory: factory, log: log)
    #@storage = Google::Cloud::Storage.new
  end

  def server
    bot.servers.fetch(@server_id)
  end

  def channels
    server.channels.index_by(&:name)
  end

  def shutdown!
    log.info("Shutting down...")
    bot.stop
    exit(0)
  end

  def register_commands
    log.debug("Registering bot commands...")

    @@messages.each do |name:, regex:|
      bot.message(contains: regex, &method(:"do_#{name}"))
    end

    bot.message(contains: %r!https?://\w+\.donmai\.us/posts/\d+!i, &method(:do_convert_post_links))
    bot.command(:hi, description: "Say hi to Fumimi: `/hi`", &method(:do_hi))
    bot.command(:calc, description: "Calculate a math expression", &method(:do_calc))
    bot.command(:ruby, description: "Evaluate a ruby expression", &method(:do_ruby))
    bot.command(:comments, description: "List comments: `/comments <tags>`", &method(:do_comments))
    bot.command(:forum, description: "List forum posts: `/forum <text>`", &method(:do_forum))
    #bot.command(:logs, description: "Dump channel log in JSON format: `/logs <channel-name>`", &method(:do_logs))
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

  def initiate_shutdown!
    @initiate_shutdown = true
  end
end
