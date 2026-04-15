require "test_helper"

class PixivEventTest < Minitest::Test
  include TestMocks

  def test_pixiv_event
    msgs = mock_event("pixiv #12345") => { msgs:, ** }

    assert_equal 1, msgs.length
    assert_equal "https://www.pixiv.net/artworks/12345", msgs.first
  end
end
