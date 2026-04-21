require "test_helper"

class PostEventTest < ApplicationTest
  ASSET_FOOTER_PATTERN = /^\d+x\d+ \(\d+\.\d+ \w+ \w+\)$/

  def test_asset
    embeds = mock_event("asset #123", nsfw_channel: false) => { embeds:, ** }
    assert_equal 1, embeds.length
    asset = embeds.first

    assert_equal "asset #123", asset.title
    assert_nil asset.color
    assert_equal "https://danbooru.donmai.us/media_assets/123", asset.url
    assert_nil asset.image
    assert_match ASSET_FOOTER_PATTERN, asset.footer.text
    assert asset.timestamp
  end

  def test_no_asset
    embeds = mock_event("asset #999999999") => { embeds:, ** }
    assert_equal 0, embeds.length
  end
end
