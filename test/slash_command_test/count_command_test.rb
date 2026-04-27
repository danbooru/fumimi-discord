require "test_helper"

class CountCommandTest < ApplicationTest
  def test_find_results
    mock_slash_command("/count", args: { tags: "age:<1d" }) => { replies: }

    assert_match(/Post count for `age:<1d`: [\d,]+./, replies.first)
  end

  def test_timeout
    mock_slash_command("/count", args: { tags: "-has:commentary commentary_request" }) => { reply_embeds:, replies: }

    assert_equal [], replies
    assert_equal 1, reply_embeds.length

    error = reply_embeds.first
    assert_equal "Timeout Encontered!", error.title
  end
end
