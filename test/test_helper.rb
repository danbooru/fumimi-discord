ENV["APP_ENV"] = "test"
require_relative "../lib/fumimi"

require "minitest/autorun"
require "mocha/minitest"
require "active_support/testing/parallelization"
require "active_support/testing/parallelize_executor"

unless ENV["RUBY_LSP_TEST_RUNNER"] == "debug" || ENV.key?("DEBUG")
  Minitest.parallel_executor = ActiveSupport::Testing::ParallelizeExecutor.new(
    size: Concurrent.available_processor_count.to_i,
    with: :processes,
    threshold: 0,
  )
end

class ChannelMock
  attr_reader :id, :name, :messages, :embeds

  def initialize(name: "#test", id: 123, is_nsfw: false, pm: false)
    @id = id
    @name = name
    @is_nsfw = is_nsfw
    @pm = pm
    @messages = []
    @embeds = []
  end

  def send_message!(content: "", embeds: [], **_rest)
    @messages << content
    @embeds.concat(Array(embeds))
  end

  def nsfw?
    @is_nsfw
  end

  def pm?
    @pm
  end
end

class EventMock
  attr_reader :text, :user, :channel, :message, :options, :replies, :reply_embeds

  def initialize(user:, channel:, message:, text: nil, options: {})
    @text = text
    @user = user
    @channel = channel
    @message = message
    @options = options
    @replies = []
    @reply_embeds = []
  end

  def deconstruct_keys(_keys)
    {
      messages: @channel.messages,
      embeds: @channel.embeds,
      replies: @replies,
      reply_embeds: @reply_embeds,
    }
  end

  def defer(**)
    nil
  end

  def edit_response(content: nil, embeds: nil)
    @replies << content if content
    @reply_embeds.concat(Array(embeds)) if embeds
  end
end

class ApplicationTest < Minitest::Test
  def message_mock(**options)
    stub(suppress_embeds: nil, **options)
  end

  def user_mock(id: 123, username: "tester", **options)
    stub(id:, username:, **options)
  end

  def channel_mock(**options)
    ChannelMock.new(**options)
  end

  def default_fumimi(**options)
    Fumimi::Bot.new(log: Logger.new(nil), **options)
  end

  def mock_slash_command(name, args: {}, message: message_mock, channel: channel_mock, user: user_mock, fumimi: default_fumimi)
    command_name = name.to_s.delete_prefix("/")
    command_class = Fumimi::SlashCommandRegistry.new(fumimi:).command_classes.find do |klass|
      klass.name == command_name
    end

    event = EventMock.new(channel:, user:, message:, options: args)

    command = command_class.new(fumimi, event)
    command.safe_handle_event
    event
  end

  def mock_event(text, message: message_mock, channel: channel_mock, user: user_mock, fumimi: default_fumimi)
    event = EventMock.new(text:, channel:, user:, message:)

    Fumimi::MessageEvent.respond_to_all_matches(event, fumimi:)
    event
  end

  def table_lines_for(embed)
    embed.description.split("\n").filter_map do |l|
      l.split("│").map(&:strip).map(&:presence).compact if l.start_with?("│")
    end
  end
end
