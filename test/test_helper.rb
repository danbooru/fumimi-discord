$LOAD_PATH.unshift File.expand_path("../lib", __dir__)

require "fumimi"
require "minitest/autorun"
require "minitest/mock"

USER_MOCK = Struct.new(:id, :username) do
  def roles
    []
  end
end
MESSAGE_MOCK = Struct.new(:content) do
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

class CHANNEL_MOCK
  attr_reader :name, :messages, :embeds

  def initialize(name:, is_nsfw: true)
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
end

class EVENT_MOCK
  attr_reader :text, :user, :channel, :message

  def initialize(text:, user:, channel:)
    @text = text
    @user = user
    @channel = channel
    @message = MESSAGE_MOCK.new(text)
  end

  def captured
    {
      msgs: @channel.messages,
      embeds: @channel.embeds,
      suppress_embeds_calls: @message.suppress_embeds_calls,
    }
  end

  def send_message(msg)
    @channel.send_message(msg)
    MESSAGE_MOCK.new(msg)
  end

  def drain
    nil
  end
end

class SLASH_EVENT_MOCK
  attr_reader :user, :channel, :channels, :options, :replies, :reply_embeds, :deferred

  def initialize(user:, channel:, channels:, options: {})
    @user = user
    @channel = channel
    @channels = channels
    @options = options
    @replies = []
    @reply_embeds = []
    @deferred = false
  end

  def is_a?(val)
    val == Discordrb::Events::ApplicationCommandEvent || super
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

  def captured
    {
      replies: @replies,
      messages: @channel.messages,
      reply_embeds: @reply_embeds,
      deferred: @deferred,
    }
  end
end

module TestMocks
  def cache
    Zache.new
  end

  def user_mock
    USER_MOCK.new(123, "tester")
  end

  def channel_mock(nsfw_channel:)
    CHANNEL_MOCK.new(name: "#test", is_nsfw: nsfw_channel)
  end

  def log
    Logger.new($stderr, level: Logger::DEBUG)
  end

  def slash_event_mock(nsfw_channel:, args:)
    channel = channel_mock(nsfw_channel:)
    SLASH_EVENT_MOCK.new(user: user_mock,
                         channel: channel,
                         channels: { channel.name => channel },
                         options: args)
  end

  def default_booru
    Danbooru.new
  end

  def mock_slash_command(name, args:, nsfw_channel: false, booru: default_booru)
    command_name = name.to_s.delete_prefix("/")
    command_class = ObjectSpace.each_object(Class).find do |klass|
      klass < Fumimi::SlashCommand && klass.name == command_name
    end

    raise ArgumentError, "Unknown slash command: #{name}" unless command_class

    event = slash_event_mock(nsfw_channel:, args:)

    command = command_class.new(event, log: log, booru: booru, cache: cache)
    command.safe_handle_event
    event.captured
  end

  def mock_event(text, nsfw_channel: false)
    event = EVENT_MOCK.new(text: text,
                           channel: channel_mock(nsfw_channel:),
                           user: user_mock)

    Fumimi::Event.respond_to_all_matches(event_mock(nsfw_channel:), log: log, booru: default_booru)
    event.captured
  end

  def table_lines_for(embed)
    embed.description.split("\n").filter_map do |l|
      l.split("│").map(&:strip).map(&:presence).compact if l.start_with?("│")
    end
  end
end
