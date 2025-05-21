module Fumimi::Commands
  class CommandArgumentError < StandardError; end

  def self.command(name, &block)
    define_method(:"do_#{name}") do |event, *args|
      message = event.send_message "*Please wait warmly until Fumimi is ready. This may take up to 60 seconds.*"
      event.channel.start_typing

      instance_exec(event, *args, &block)
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
    return unless event.user.owner?

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
    return unless event.user.owner?

    code = args.join(" ")
    result = instance_eval(code)
    event << "`#{result.inspect}`"
  end

  def do_forum(event, *args)
    event.channel.start_typing

    limit = args.grep(/limit:(\d+)/i) { ::Regexp.last_match(1).to_i }.first
    limit ||= 3
    limit = [10, limit].min
    body = args.grep_v(/limit:(\d+)/i).join(" ")

    forum_posts = booru.forum_posts.index("search[body_matches]": body, limit: limit)
    Fumimi::Model::ForumPost.render_forum_posts(event.channel, forum_posts)

    nil
  end

  def do_comments(event, *tags)
    limit = tags.grep(/limit:(\d+)/i) { ::Regexp.last_match(1).to_i }.first
    limit ||= 3
    limit = [10, limit].min
    tags = tags.grep_v(/limit:(\d+)/i)

    comments = booru.comments.index("search[post_tags_match]": tags.join(" "), limit: limit)
    Fumimi::Model::Comment.render_comments(event.channel, comments)

    nil
  end
end
