require "test_helper"

class ForumEventTest < Minitest::Test
  include TestMocks

  def test_forum_event
    embeds = mock_event("forum #123") => { embeds:, ** }
    assert_equal 1, embeds.length
    assert_equal "tag count reset in /post?", embeds.first.title
  end

  def test_no_forum
    embeds = mock_event("forum #99999999") => { embeds:, ** }
    assert_equal 0, embeds.length
  end
end
