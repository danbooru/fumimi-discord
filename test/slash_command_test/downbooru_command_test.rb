require "test_helper"

class DownbooruCommandTest < ApplicationTest
  def test_responds_to_command
    mock_slash_command("/downbooru") => { reply_embeds:, ** }

    assert_equal 1, reply_embeds.length
    assert_equal "All good! Site's up!", reply_embeds.first.title
  end

  def test_timeout_error_returns_downbooru_error_embed
    posts = Object.new
    posts.define_singleton_method(:index) do |*_args|
      raise Timeout::Error
    end

    fumimi = default_fumimi
    fumimi.booru.define_singleton_method(:posts) { posts }

    mock_slash_command("/downbooru", fumimi:) => { reply_embeds:, ** }

    assert_equal 1, reply_embeds.length
    assert_equal "Downbooru", reply_embeds.first.title
    assert_equal "The site is down!", reply_embeds.first.description
  end

  def test_maintenance_error_returns_maintenance_embed
    posts = Object.new
    posts.define_singleton_method(:index) do |*_args|
      raise Danbooru::Exceptions::MaintenanceError
    end

    fumimi = default_fumimi
    fumimi.booru.define_singleton_method(:posts) { posts }

    mock_slash_command("/downbooru", fumimi:) => { reply_embeds:, ** }

    assert_equal 1, reply_embeds.length
    assert_equal "Downbooru", reply_embeds.first.title
    assert_equal "The site is down for maintenance!", reply_embeds.first.description
  end
end
