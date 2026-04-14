require "test_helper"

class CommentEventTest < Minitest::Test
  include TestMocks

  POST_FOOTER_PATTERN = /\d+⇧ \d+♥ | Rating: [GSQE] | \d+x\d+ (\d+.\d+ \d+ \w+)/

  def test_comment_event
    embeds = mock_event("comment #123") => { embeds:, ** }
    assert_equal 1, embeds.length
    assert_match(/whatever/, embeds.first.description)
  end

  def test_no_comment
    embeds = mock_event("comment #999999999") => { embeds:, ** }
    assert_equal 0, embeds.length
  end
end
