require "test_helper"

class TopicEventTest < Minitest::Test
  include TestMocks

  def test_forum_event
    embeds = mock_event("topic #123") => { embeds:, ** }
    assert_equal 1, embeds.length
    assert_equal "Artist wiki - Note field", embeds.first.title
  end

  def test_no_topic
    embeds = mock_event("topic #1010101") => { embeds:, ** }
    assert_equal 0, embeds.length
  end
end
