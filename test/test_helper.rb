$LOAD_PATH.unshift File.expand_path("../lib", __dir__)

require "fumimi"
require "debug"
require "minitest/autorun"
require "minitest/mock"
require "active_support/test_case"

UserMock = Struct.new(:id, :username) do
  def roles
    []
  end
end

MessageMock = Struct.new(:content) do
  def delete
    nil
  end

  def suppress_embeds
    @suppress_embeds_calls = suppress_embeds_calls + 1
    nil
  end

  def suppress_embeds_calls
    @suppress_embeds_calls ||= 0
  end
end

class ChannelMock
  attr_reader :id, :name, :messages, :embeds

  def initialize(name:, id: 123, is_nsfw: true, pm: false)
    @id = id
    @name = name
    @is_nsfw = is_nsfw
    @messages = []
    @embeds = []
  end

  def send_embed(msg = nil, embeds = nil, *_rest)
    @messages << msg unless msg.nil?
    @embeds.concat(Array(embeds)) if embeds
    true
  end

  def send_message(msg = nil, _tts = false, embeds = nil, *_rest)
    @messages << msg
    @embeds.concat(Array(embeds)) if embeds
    true
  end

  def nsfw?
    @is_nsfw
  end

  def pm?
    @pm
  end
end

class ServerMock
  attr_reader :channels

  def initialize(channels)
    @channels = channels
  end
end

class EventMock
  attr_reader :text, :user, :channel, :message, :options, :replies, :reply_embeds, :deferred

  def initialize(user:, channel:, text: nil, options: {})
    @text = text
    @user = user
    @channel = channel
    @message = MessageMock.new(text) if text
    @application_command_event = text.nil?
    @options = options
    @replies = []
    @reply_embeds = []
    @deferred = false
    @channels = { channel.id => channel }
  end

  def is_a?(val)
    (@application_command_event && val == Discordrb::Events::ApplicationCommandEvent) || super
  end

  def respond_to?(method_name, include_private = false)
    return false if method_name.to_sym == :edit_response && !@application_command_event

    super
  end

  def channels
    { channel.name => channel }
  end

  def server
    ServerMock.new(@channels.values)
  end

  def captured
    {
      messages: @channel.messages,
      embeds: @channel.embeds,
      replies: @replies,
      reply_embeds: @reply_embeds,
      suppress_embeds_calls: @message&.suppress_embeds_calls || 0,
      deferred: @deferred,
    }
  end

  def send_message(msg)
    @channel.send_message(msg)
    MessageMock.new(msg)
  end

  def defer(ephemeral: false)
    @deferred = true
    ephemeral
  end

  def edit_response(content: nil, embeds: nil)
    @replies << content if content
    @reply_embeds.concat(Array(embeds)) if embeds
  end

  def drain
    nil
  end

  def sleep(_seconds = nil)
    nil
  end
end

class ApplicationTest < ActiveSupport::TestCase
  parallelize(workers: :number_of_processors, with: :threads)

  def cache
    Zache.new
  end

  def user_mock(user_id: 123)
    UserMock.new(user_id, "tester")
  end

  def channel_mock(nsfw_channel:)
    ChannelMock.new(name: "#test", is_nsfw: nsfw_channel)
  end

  def log
    Logger.new($stderr, level: Logger::FATAL)
  end

  def default_fumimi(**options)
    Fumimi.new(
      server_id: ENV.fetch("DISCORD_SERVER_ID", nil),
      client_id: ENV.fetch("DISCORD_CLIENT_ID", nil),
      token: ENV.fetch("DISCORD_TOKEN", nil),
      booru_url: ENV.fetch("BOORU_URL", "https://danbooru.donmai.us"),
      booru_user: ENV.fetch("BOORU_USER", nil),
      booru_api_key: ENV.fetch("BOORU_API_KEY", nil),
      signoz_api_key: ENV.fetch("SIGNOZ_API_KEY", nil),
      log: Logger.new(nil),
      **options,
    )
  end

  def mock_slash_command(name, args: {}, nsfw_channel: false, fumimi: nil, user_id: 123, **options)
    fumimi ||= default_fumimi(**options)
    command_name = name.to_s.delete_prefix("/")
    command_class = ObjectSpace.each_object(Class).find do |klass|
      klass < Fumimi::SlashCommand && klass.name == command_name
    end

    raise ArgumentError, "Unknown slash command: #{name}" unless command_class

    event = EventMock.new(user: user_mock(user_id:), channel: channel_mock(nsfw_channel:), options: args)

    command = command_class.new(event, fumimi:)
    command.safe_handle_event
    event.captured
  end

  def mock_event(text, nsfw_channel: false, **options)
    event = EventMock.new(text: text, channel: channel_mock(nsfw_channel:), user: user_mock)

    Fumimi::Event.respond_to_all_matches(event, fumimi: default_fumimi(**options))
    event.captured
  end

  def table_lines_for(embed)
    embed.description.split("\n").filter_map do |l|
      l.split("│").map(&:strip).map(&:presence).compact if l.start_with?("│")
    end
  end
end
