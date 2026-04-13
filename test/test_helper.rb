$LOAD_PATH.unshift File.expand_path("../lib", __dir__)

require "fumimi"
require "minitest/autorun"
require "minitest/mock"

USER_MOCK = Struct.new(:id, :username)
class CHANNEL_MOCK
  attr_reader :name, :messages, :embeds

  def initialize(name:, is_nsfw: true)
    @name = name
    @is_nsfw = is_nsfw
    @messages = []
    @embeds = []
  end

  def send_embed(msg = nil, embeds = nil)
    @messages << msg unless msg.nil?
    @embeds.concat(Array(embeds)) if embeds
    true
  end

  def send_message(msg)
    @messages << msg
    true
  end

  def nsfw?
    @is_nsfw
  end

  def start_typing
    nil
  end
end

class EVENT_MOCK
  attr_reader :text, :user, :channel

  def initialize(text:, user:, channel:)
    @text = text
    @user = user
    @channel = channel
  end

  def captured
    {
      msgs: @channel.messages,
      embeds: @channel.embeds,
    }
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

FUMIMI_MOCK = Class.new do
  include Fumimi::Events

  define_method(:log) { Logger.new(File::NULL) }
  define_method(:booru) { Danbooru.new(log: Logger.new(File::NULL)) }
end

module TestMocks
  def slash_event_mock(args: {}, user_id: 123, username: "tester", channel_name: "#test", is_nsfw: true)
    user_mock = USER_MOCK.new(user_id, username)
    channel_mock = CHANNEL_MOCK.new(name: channel_name, is_nsfw: is_nsfw)

    SLASH_EVENT_MOCK.new(user: user_mock, channel: channel_mock, channels: { channel_name => channel_mock },
                         options: args)
  end

  def mock_slash_command(name, args: {}, user_id: 123, username: "tester", channel_name: "#test", is_nsfw: true)
    command_name = name.to_s.delete_prefix("/")
    command_class = ObjectSpace.each_object(Class).find do |klass|
      klass < Fumimi::Command && klass.name == command_name
    end
    raise ArgumentError, "Unknown slash command: #{name}" unless command_class

    event = slash_event_mock(args:, user_id:, username:, channel_name:, is_nsfw:)
    command = command_class.new(event)
    command.safe_handle_event
    event.captured
  end

  def event_mock(text)
    user_mock = USER_MOCK.new(123, "tester")
    channel_mock = CHANNEL_MOCK.new(name: "#test", is_nsfw: true)
    EVENT_MOCK.new(text:, user: user_mock, channel: channel_mock)
  end

  def fumimi
    @fumimi ||= FUMIMI_MOCK.new
  end

  def mock_event(mocked_text)
    event = event_mock(mocked_text)
    fumimi.respond_to_embeds(event)
    event.captured
  end

  def setup_booru
    factory = {
      posts: Fumimi::Model::Post,
      tags: Fumimi::Model::Tag,
      comments: Fumimi::Model::Comment,
      forum_posts: Fumimi::Model::ForumPost,
      users: Fumimi::Model::User,
      wiki_pages: Fumimi::Model::WikiPage,
    }.with_indifferent_access

    Danbooru.new(factory: factory)
  end
end
