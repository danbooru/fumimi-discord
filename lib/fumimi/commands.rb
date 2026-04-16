require "zache"

require "fumimi/exceptions"

module Fumimi::Commands # rubocop:disable Metrics/ModuleLength
  OWNERS = [310167383912349697, 1373735183425208331].freeze # rubocop:disable Style/NumericLiterals

  zache = Zache.new

  def self.command(name, &block)
    define_method(:"do_#{name}") do |event, *args|
      execute_and_rescue_errors(event) do
        instance_exec(event, *args, &block)
      end
    end
  end

  def do_say(event, *args)
    raise Fumimi::Exceptions::PermissionError unless OWNERS.include? event.user.id

    channel_name = args.shift
    message = args.join(" ")

    channels[channel_name].send_message(message)
  end

  command :ruby do |event, *args|
    raise Fumimi::Exceptions::PermissionError unless OWNERS.include? event.user.id

    code = args.join(" ")
    result = instance_eval(code)
    event << "`#{result.inspect}`"
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
      report = Fumimi::Report::UploadReport.new(event, booru, tags)
      report.send_embed(embed)
    end
  end

  command :uploader_stats do |event, *tags|
    event.channel.start_typing

    event.channel.send_embed do |embed|
      report = Fumimi::Report::UploaderReport.new(event, booru, tags)
      report.send_embed(embed)
    end
  end

  command :post_search_stats do |event, *tags|
    event.channel.start_typing

    event.channel.send_embed do |embed|
      report = Fumimi::PostSearchReport.new(event, booru, tags)
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
      report = Fumimi::Report::ModqueueReport.new(event, booru, tags)
      report.send_embed(embed)
    end
  end

  command :downbooru do |event, *_tags|
    event.channel.start_typing

    begin
      booru.posts.index({ limit: 1 }, { timeout: 2 })
    rescue Timeout::Error
      raise Danbooru::Exceptions::DownbooruError
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

  command :searches do |event, *tags|
    event.channel.start_typing
    event.channel.send_embed do |embed|
      report = Fumimi::AnalyticsReport.new(event, tags, log, zache)
      report.send_embed(embed)
    end
  end

  command :allsearches do |event, *args|
    if event.user.roles.none? { |role| %w[mod admin].include? role.name.downcase }
      raise Fumimi::Exceptions::PermissionError
    end

    days = args.first.to_i
    raise Fumimi::Exceptions::CommandArgumentError, "First argument must be # of days" if days < 1

    tags = args[1..]

    event.channel.start_typing
    event.channel.send_embed do |embed|
      report = Fumimi::AnalyticsReport.new(event, tags, log, zache, range: days.days)
      report.send_embed(embed)
    end
  end
  nil
end
