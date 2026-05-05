require "test_helper"

class SearchEventTest < ApplicationTest
  POST_FOOTER_PATTERN = /^-?\d+⇧ \d+♥  •  Rating: [GSQE]  •  \d+x\d+ \(\d+\.\d+ \w+ \w+\)$/

  def test_search
    mock_event("{{id:3}}") => { embeds: }

    assert_equal 1, embeds.length
    post = embeds.first

    assert_equal "post #3", post.title
    assert_nil post.color
    assert_equal "https://danbooru.donmai.us/posts/3", post.url
    assert_match %r{^https://cdn.donmai.us/original/}, post.image.url
    assert_match POST_FOOTER_PATTERN, post.footer.text
    assert post.timestamp
  end

  def test_nsfw_search_on_sfw_channel
    mock_event("{{id:12}}") => { embeds: }

    assert_equal 1, embeds.length
    post = embeds.first

    assert_equal "post #12", post.title
    assert_nil post.color
    assert_equal "https://danbooru.donmai.us/posts/12", post.url
    assert_nil post.image
    assert_match POST_FOOTER_PATTERN, post.footer.text
    assert post.timestamp
  end

  def test_nsfw_search_on_nsfw_channel
    mock_event("{{id:12}}", channel: channel_mock(is_nsfw: true)) => { embeds: }

    assert_equal 1, embeds.length
    post = embeds.first

    assert_equal "post #12", post.title
    assert_nil post.color
    assert_equal "https://danbooru.donmai.us/posts/12", post.url
    assert_match %r{^https://cdn.donmai.us/original/}, post.image.url
    assert_match POST_FOOTER_PATTERN, post.footer.text
    assert post.timestamp
  end

  def test_search_no_results
    mock_event("{{qwoigqeoirgjhq2eroj1304hj}}") => { embeds: }

    assert_equal 0, embeds.length
  end
end
