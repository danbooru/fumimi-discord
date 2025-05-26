module Fumimi::Commands
  class CommandArgumentError < StandardError; end
  class PermissionError < StandardError; end

  def self.command(name, &block)
    define_method(:"do_#{name}") do |event, *args|
      message = event.send_message "*Please wait warmly until Fumimi is ready. This may take up to 60 seconds.*"
      event.channel.start_typing

      instance_exec(event, *args, &block)
    rescue PermissionError
      event.drain
    rescue CommandArgumentError => e
      event << "```#{e}```"
    rescue StandardError, RestClient::Exception => e
      event.drain
      @log.error e
      event << "Exception: #{e}.\n"
      event << "https://i.imgur.com/0CsFWP3.png"
    ensure
      message.delete
      nil
    end
  end

  def do_hi(event, *args)
    event.send_message "Command received. Deleting all animes."
    sleep 1

    event.send_message "5..."
    sleep 1
    event.send_message "4..."
    sleep 1
    event.send_message "3..."
    sleep 1
    event.send_message "2..."
    sleep 1
    event.send_message "1..."
    sleep 1

    event.send_message "Done! Animes deleted."
  end

  def do_say(event, *args)
    raise PermissionError if event.user.id != 310167383912349697 # rubocop:disable Style/NumericLiterals

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
    raise PermissionError if event.user.id != 310167383912349697 # rubocop:disable Style/NumericLiterals

    code = args.join(" ")
    result = instance_eval(code)
    event << "`#{result.inspect}`"
  end

  def do_forum(event, *args)
    event.channel.start_typing

    limit = args.grep(/limit:(\d+)/i) { ::Regexp.last_match(1).to_i }.first
    limit ||= 3
    limit = [5, limit].min
    body = args.grep_v(/limit:(\d+)/i).join(" ")

    forum_posts = booru.forum_posts.index("search[body_matches]": body, limit: limit)
    embeds = forum_posts.map do |forum_post|
      next if forum_post.hidden?

      embed = Discordrb::Webhooks::Embed.new
      forum_post.embed(embed, event.channel)
    end
    event.channel.send_embed("", embeds) unless embeds.blank?
    nil
  end

  def do_comments(event, *tags)
    limit = tags.grep(/limit:(\d+)/i) { ::Regexp.last_match(1).to_i }.first
    limit ||= 3
    limit = [5, limit].min
    tags = tags.grep_v(/limit:(\d+)/i)

    comments = booru.comments.index("search[post_tags_match]": tags.join(" "), limit: limit)
    embeds = comments.map do |comment|
      embed = Discordrb::Webhooks::Embed.new
      comment.embed(embed, event.channel)
    end
    event.channel.send_embed("", embeds) unless embeds.blank?
    nil
  end

  def do_burs(event, *args)
    event.channel.start_typing

    limit = args.grep(/limit:(\d+)/i) { ::Regexp.last_match(1).to_i }.first || 10
    limit = limit.clamp(1, 10)

    bulk_update_requests = booru.bulk_update_requests.index(limit: 1000, "search[status]": "pending")

    message = "**Total pending BURs**: #{bulk_update_requests.count}\n\n"
    message += "Top #{limit} topics by pending requests:\n"
    grouped = bulk_update_requests.group_by { |bur| bur.forum_topic.id }.sort_by { |_, bur| -bur.count }
    message += grouped.first(limit).map do |_, burs|
      topic = burs.first.forum_topic
      topic_pending_link = "#{booru.url}/bulk_update_requests?search[forum_topic_id]=#{topic.id}&search[status]=pending"
      "* [topic ##{topic.id}: #{topic.title}](<#{topic_pending_link}>) - #{burs.count} pending BURs"
    end.join("\n")
    event.channel.send_message(message)
    nil
  end

  nil
end
