require "zache"

module Fumimi::Commands
  OWNERS = [310167383912349697, 1373735183425208331].freeze # rubocop:disable Style/NumericLiterals

  zache = Zache.new

  def self.command(name, &block)
    define_method(:"do_#{name}") do |event, *args|
      execute_and_rescue_errors(event) do
        instance_exec(event, *args, &block)
      end
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
    raise Fumimi::Exceptions::PermissionError unless OWNERS.include? event.user.id

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
    raise Fumimi::Exceptions::PermissionError unless OWNERS.include? event.user.id

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

    forum_posts = booru.forum_posts.index("search[body_matches]": body,
                                          "search[topic][is_private]": false,
                                          limit: limit)
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

  command :burs do |event, *args|
    event.channel.start_typing

    event.channel.send_embed do |embed|
      Fumimi::Model::BulkUpdateRequest.send_embed_for_stats(embed, booru)
    end
  end

  command :related_tags do |event, *args|
    event.channel.start_typing

    event.channel.send_embed do |embed|
      report = Fumimi::RelatedReport.new(event, booru, args)
      report.send_embed(embed)
    end
  end

  command :upload_stats do |event, *tags|
    event.channel.start_typing

    event.channel.send_embed do |embed|
      report = Fumimi::PostReport::UploadReport.new(event, booru, tags)
      report.send_embed(embed)
    end
  end

  command :uploader_stats do |event, *tags|
    event.channel.start_typing

    event.channel.send_embed do |embed|
      report = Fumimi::PostReport::UploaderReport.new(event, booru, tags)
      report.send_embed(embed)
    end
  end

  command :approver_stats do |event, *tags|
    event.channel.start_typing

    event.channel.send_embed do |embed|
      report = Fumimi::PostReport::ApproverReport.new(event, booru, tags)
      report.send_embed(embed)
    end
  end

  command :search_stats do |event, *tags|
    event.channel.start_typing

    event.channel.send_embed do |embed|
      report = Fumimi::SearchReport.new(event, booru, tags)
      report.send_embed(embed)
    end
  end

  command :raffle_report do |event, *args|
    topic_id = args.grep(/^(\d+)$/) { ::Regexp.last_match(1).to_i }.first

    if topic_id.blank?
      event.send_message "You must supply a forum topic ID!"
    else
      event.channel.start_typing

      event.channel.send_embed do |embed|
        report = Fumimi::RaffleReport.new(event, booru, zache, topic_id)
        report.send_embed(embed)
      end
    end
  end

  command :raffle_pick do |event, *args|
    raise Fumimi::Exceptions::PermissionError unless OWNERS.include? event.user.id

    topic_id = args.grep(/^(\d+)$/).first.to_i
    winner_count = args.grep(/^(\d+)$/).second.to_i

    if topic_id.blank?
      event.send_message "You must supply a forum topic ID!"
    else
      event.channel.start_typing
      winner_count = 20 if winner_count.zero?

      event.channel.send_embed do |embed|
        report = Fumimi::RaffleReport.new(event, booru, zache, topic_id)
        report.send_winner_embed(embed, winner_count)
      end
    end
  end

  command :modqueue do |event, *tags|
    event.channel.start_typing

    event.channel.send_embed do |embed|
      report = Fumimi::PostReport::ModqueueReport.new(event, booru, tags)
      report.send_embed(embed)
    end
  end

  command :downbooru do |event, *_tags|
    event.channel.start_typing

    begin
      booru.posts.index({ limit:1 }, { timeout: 2 })
    rescue Timeout::Error
      raise Danbooru::Response::DownbooruError
    end

    event.channel.send_embed do |embed|
      embed.title = "All good! Site's up!"
      embed.image = Discordrb::Webhooks::EmbedImage.new(url: "https://i.imgur.com/ik5HdCp.png")
      embed
    end
  end

  command :future do |event, *_tags|
    event.channel.start_typing

    event.channel.send_embed do |embed|
      report = Fumimi::FutureReport.new(event, booru)
      report.send_embed(embed)
    end
  end
  nil
end
