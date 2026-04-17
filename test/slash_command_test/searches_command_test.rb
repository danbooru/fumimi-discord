require "test_helper"

class SearchesCommandTest < Minitest::Test
  include TestMocks

  def test_handles_missing_credentials
    mock_slash_command("/searches", args: { tags: "cat_ears" }) => { reply_embeds:, ** }

    assert_equal 1, reply_embeds.length
    error = reply_embeds.first
    assert_equal "Exception Encountered!", error.title
  end
end
