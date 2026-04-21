require "test_helper"

class PostStatsCommandTest < ApplicationTest
  def test_responds_to_command
    mock_slash_command("/post_stats", args: { tags: "age:<1d" }) => { reply_embeds:, ** }

    assert_equal 1, reply_embeds.length
    report = reply_embeds.first
    assert_equal "Post Stats", report.title
    assert report.description
  end
end
