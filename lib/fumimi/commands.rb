require "zache"

require "fumimi/exceptions"

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
  nil
end
