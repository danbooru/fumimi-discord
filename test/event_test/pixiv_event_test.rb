require "test_helper"

class PixivEventTest < Minitest::Test
  include TestMocks

  def test_pixiv_event
    messages = mock_event("pixiv #12345") => { messages:, ** }

    assert_equal 1, messages.length
    assert_equal "https://www.pixiv.net/artworks/12345", messages.first
  end
end
