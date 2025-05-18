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
