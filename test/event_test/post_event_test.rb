require "test_helper"

class PostEventTest < Minitest::Test
  include TestMocks

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
    with_mocked_censored_tags(["1girl"]) do
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
  end

  def test_censored_post_on_nsfw_channel
    with_mocked_censored_tags(["1girl"]) do
      embeds = mock_event("post #12", nsfw_channel: true) => { embeds:, ** }
      assert_equal 1, embeds.length
      post = embeds.first

      assert_equal "post #12", post.title
      assert_nil post.color
      assert_equal "https://danbooru.donmai.us/posts/12", post.url
      assert_nil post.image
      assert_match POST_FOOTER_PATTERN, post.footer.text
      assert post.timestamp
    end
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

  def test_no_post
    embeds = mock_event("post #6") => { embeds:, ** }
    assert_equal 0, embeds.length
  end

  private

  def with_mocked_censored_tags(tags)
    original_tags = Fumimi::Model::Post::CENSORED_TAGS
    Fumimi::Model::Post.send(:remove_const, :CENSORED_TAGS)
    Fumimi::Model::Post.const_set(:CENSORED_TAGS, tags)
    yield
  ensure
    Fumimi::Model::Post.send(:remove_const, :CENSORED_TAGS)
    Fumimi::Model::Post.const_set(:CENSORED_TAGS, original_tags)
  end
end
