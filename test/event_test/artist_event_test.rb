require "test_helper"

class ArtistEventTest < Minitest::Test
  include TestMocks

  def test_artist_event
    msgs = mock_event("artist #99999, artist #99991") => { msgs:, ** }
    assert_equal 1, msgs.length

    assert_equal "https://danbooru.donmai.us/artists/99999\nhttps://danbooru.donmai.us/artists/99991", msgs.first.strip
  end
end
