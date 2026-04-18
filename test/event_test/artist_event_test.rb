require "test_helper"

class ArtistEventTest < Minitest::Test
  include TestMocks

  def test_artist_event
    messages = mock_event("artist #99999, artist #99991") => { messages:, ** }
    assert_equal 1, messages.length

    assert_equal "https://danbooru.donmai.us/artists/99999\nhttps://danbooru.donmai.us/artists/99991",
                 messages.first.strip
  end
end
