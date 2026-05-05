require "test_helper"

class ArtistEventTest < ApplicationTest
  def test_artist_event
    mock_event("artist #99999, artist #99991") => { messages: }

    assert_equal(["https://danbooru.donmai.us/artists/99999\nhttps://danbooru.donmai.us/artists/99991"], messages)
  end
end
