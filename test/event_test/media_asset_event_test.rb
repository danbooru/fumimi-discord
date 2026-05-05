require "test_helper"

class PostEventTest < ApplicationTest
  def test_asset
    mock_event("asset #123") => { embeds: }

    assert_equal 1, embeds.length
    asset = embeds.first

    assert_equal "asset #123", asset.title
    assert_nil asset.color
    assert_equal "https://danbooru.donmai.us/media_assets/123", asset.url
    assert_nil asset.image
    assert_match(/^\d+x\d+ \(\d+\.\d+ \w+ \w+\)$/, asset.footer.text)
    assert asset.timestamp
  end

  def test_no_asset
    mock_event("asset #999999999") => { embeds: }

    assert_equal 0, embeds.length
  end
end
