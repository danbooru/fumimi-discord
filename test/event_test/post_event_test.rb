require "test_helper"

class PostEventTest < ApplicationTest
  POST_FOOTER_PATTERN = /^-?\d+⇧ \d+♥  •  Rating: [GSQE]  •  \d+x\d+ \(\d+\.\d+ \w+ \w+\)$/

  def test_sfw_post_on_sfw_channel
    embeds = mock_event("post #3", nsfw_channel: false) => { embeds:, ** }
    assert_equal 1, embeds.length
    post = embeds.first

    assert_equal "post #3", post.title
    assert_nil post.color
    assert_equal "https://danbooru.donmai.us/posts/3", post.url
    assert_match %r{^https://cdn.donmai.us/original/}, post.image.url
    assert_match POST_FOOTER_PATTERN, post.footer.text
    assert post.timestamp
  end

  def test_sfw_post_on_nsfw_channel
    embeds = mock_event("post #3", nsfw_channel: true) => { embeds:, ** }
    assert_equal 1, embeds.length
    post = embeds.first

    assert_equal "post #3", post.title
    assert_nil post.color
    assert_equal "https://danbooru.donmai.us/posts/3", post.url
    assert_match %r{^https://cdn.donmai.us/original/}, post.image.url
    assert_match POST_FOOTER_PATTERN, post.footer.text
    assert post.timestamp
  end

  def test_nsfw_post_on_sfw_channel
    embeds = mock_event("post #12", nsfw_channel: false) => { embeds:, ** }
    assert_equal 1, embeds.length
    post = embeds.first

    assert_equal "post #12", post.title
    assert_nil post.color
    assert_equal "https://danbooru.donmai.us/posts/12", post.url
    assert_nil post.image
    assert_match POST_FOOTER_PATTERN, post.footer.text
    assert post.timestamp
  end

  def test_nsfw_post_on_nsfw_channel
    embeds = mock_event("post #12", nsfw_channel: true) => { embeds:, ** }
    assert_equal 1, embeds.length
    post = embeds.first

    assert_equal "post #12", post.title
    assert_nil post.color
    assert_equal "https://danbooru.donmai.us/posts/12", post.url
    assert_match %r{^https://cdn.donmai.us/original/}, post.image.url
    assert_match POST_FOOTER_PATTERN, post.footer.text
    assert post.timestamp
  end

  def test_censored_post_on_sfw_channel
    embeds = mock_event("post #12", nsfw_channel: false, censored_tags: ["1girl"]) => { embeds:, ** }
    assert_equal 1, embeds.length
    post = embeds.first

    assert_equal "post #12", post.title
    assert_nil post.color
    assert_equal "https://danbooru.donmai.us/posts/12", post.url
    assert_nil post.image
    assert_match POST_FOOTER_PATTERN, post.footer.text
    assert post.timestamp
  end

  def test_censored_post_on_nsfw_channel
    embeds = mock_event("post #12", nsfw_channel: true, censored_tags: ["1girl"]) => { embeds:, ** }
    assert_equal 1, embeds.length
    post = embeds.first

    assert_equal "post #12", post.title
    assert_nil post.color
    assert_equal "https://danbooru.donmai.us/posts/12", post.url
    assert_nil post.image
    assert_match POST_FOOTER_PATTERN, post.footer.text
    assert post.timestamp
  end

  def test_video_post
    embeds = mock_event("post #1722315", nsfw_channel: true) => { embeds:, ** }
    assert_equal 1, embeds.length
    post = embeds.first

    assert_equal "post #1722315", post.title
    assert_equal Fumimi::Colors::YELLOW, post.color
    assert_equal "https://danbooru.donmai.us/posts/1722315", post.url
    assert_match %r{^https://cdn.donmai.us/360x360/}, post.image.url
    assert_match POST_FOOTER_PATTERN, post.footer.text
    assert post.timestamp
  end

  def test_flash_post
    embeds = mock_event("post #3840621", nsfw_channel: true) => { embeds:, ** }
    assert_equal 1, embeds.length
    post = embeds.first

    assert_equal "post #3840621", post.title
    assert_equal Fumimi::Colors::WHITE, post.color
    assert_equal "https://danbooru.donmai.us/posts/3840621", post.url
    assert_nil post.image
    assert_match POST_FOOTER_PATTERN, post.footer.text
    assert post.timestamp
  end

  def test_banned_post
    embeds = mock_event("post #3238625") => { embeds:, ** }
    assert_equal 1, embeds.length
    post = embeds.first

    assert_equal "post #3238625", post.title
    assert_equal "https://danbooru.donmai.us/posts/3238625", post.url
    assert_nil post.image
    assert_match POST_FOOTER_PATTERN, post.footer.text
    assert post.timestamp
  end

  def test_post_event
    embeds = mock_event("https://danbooru.donmai.us/posts/3840621 https://danbooru.donmai.us/posts/1722315", nsfw_channel: true) => { embeds:, ** }
    assert_equal 2, embeds.length
    post = embeds.first

    assert_equal "post #3840621", post.title
    assert_equal Fumimi::Colors::WHITE, post.color
    assert_equal "https://danbooru.donmai.us/posts/3840621", post.url
    assert_nil post.image
    assert_match POST_FOOTER_PATTERN, post.footer.text
    assert post.timestamp
  end

  def test_post_link_deletes_original_embed
    mock_event("https://danbooru.donmai.us/posts/3840621", nsfw_channel: true) => { embeds:, suppress_embeds_calls:, ** }

    assert_equal 1, embeds.length
    assert_equal 1, suppress_embeds_calls
  end

  def test_betabooru_post_link
    embeds = mock_event("https://betabooru.donmai.us/posts/3", booru_domains: ["betabooru.donmai.us"]) => { embeds:, ** }
    assert_equal 1, embeds.length
    post = embeds.first

    assert_equal "post #3", post.title
    assert_equal "https://danbooru.donmai.us/posts/3", post.url
  end

  def test_post_subpage_link_is_ignored
    embeds = mock_event("https://danbooru.donmai.us/posts/1234/events") => { embeds:, ** }
    assert_equal 0, embeds.length
  end

  def test_post_link_with_query_params
    embeds = mock_event("https://danbooru.donmai.us/posts/1234?q=touhou") => { embeds:, ** }
    assert_equal 1, embeds.length
    assert_equal "post #1234", embeds.first.title
  end

  def test_no_post
    embeds = mock_event("post #6") => { embeds:, ** }
    assert_equal 0, embeds.length
  end
end
