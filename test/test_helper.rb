$LOAD_PATH.unshift File.expand_path("../lib", __dir__)

require "fumimi"
require "minitest/autorun"

USER_MOCK = Struct.new(:id, :username)
CHANNEL_MOCK = Struct.new(:name, :is_nsfw) do
  attr_writer :send_embed_proc, :send_msg_proc

  def send_embed(msg, embeds)
    @send_embed_proc.call(msg, embeds)
  end

  def send_message(msg)
    @send_msg_proc.call(msg)
  end

  def nsfw?
    is_nsfw
  end

  def start_typing
    nil
  end
end

EVENT_MOCK = Struct.new(:text, :user, :channel)

FUMIMI_MOCK = Class.new do
  include Fumimi::Events
  define_method(:log) { Logger.new(File::NULL) }
  define_method(:booru) { Danbooru.new(log: Logger.new(File::NULL)) }
end

module TestMocks
  def event_mock(text, &block)
    user_mock = USER_MOCK.new(123, "tester")
    channel_mock = CHANNEL_MOCK.new("#test", true)
    channel_mock.send_embed_proc = lambda { |msg, embeds|
      block&.call(msg, embeds)
      true
    }
    channel_mock.send_msg_proc = lambda { |msg|
      block&.call(msg)
      true
    }
    event_mock = EVENT_MOCK.new(text, user_mock, channel_mock)
    event_mock
  end

  def fumimi
    @fumimi ||= FUMIMI_MOCK.new
  end

  def mock_event(mocked_text)
    captured = {
      msgs: [],
      embeds: [],
    }
    event = event_mock(mocked_text) do |msg, embeds|
      captured[:msgs] << msg
      captured[:embeds] << embeds
    end

    fumimi.respond_to_embeds(event)
    captured[:msgs].flatten!
    captured[:embeds].flatten!
    captured
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
