require "test_helper"

class PostEmbedTest < Minitest::Test
  include TestMocks

  POST_FOOTER_PATTERN = /\d+⇧ \d+♥ | Rating: [G|SQE] | \d+x\d+ (\d+.\d+ \d+ \w+) | \d{4}-\d{2}-\d{2}/

  def setup
    @booru = setup_booru
    @nsfw_post = @booru.posts.show(1)

    @sfw_channel = Minitest::Mock.new
    def @sfw_channel.nsfw?
      false
    end

    @nsfw_channel = Minitest::Mock.new
    def @nsfw_channel.nsfw?
      true
    end
  end

  def test_nsfw_post_on_sfw_channel
    embed = Discordrb::Webhooks::Embed.new
    post_embed = @nsfw_post.embed(embed, @sfw_channel)

    assert_equal post_embed.title, "post #1"
    assert_equal post_embed.url, "https://danbooru.donmai.us/posts/1"
    assert_nil post_embed.image
    assert_equal post_embed.color, Fumimi::Colors::YELLOW
    assert_match(POST_FOOTER_PATTERN, post_embed.footer&.text)
  end

  def test_nsfw_post_on_nsfw_channel
    embed = Discordrb::Webhooks::Embed.new
    post_embed = @nsfw_post.embed(embed, @nsfw_channel)

    assert_equal post_embed.title, "post #1"
    assert_equal post_embed.url, "https://danbooru.donmai.us/posts/1"
    assert_equal post_embed.image&.url, "https://cdn.donmai.us/original/d3/4e/d34e4cf0a437a5d65f8e82b7bcd02606.jpg"
    assert_equal post_embed.color, Fumimi::Colors::YELLOW
    assert_match(POST_FOOTER_PATTERN, post_embed.footer&.text)
  end

  def test_sfw_post_on_nsfw_channel
    @sfw_post = @booru.posts.index(tags: "rating:general order:random", limit: 1).first
    embed = Discordrb::Webhooks::Embed.new
    post_embed = @sfw_post.embed(embed, @sfw_channel)

    assert_match(/^post #(\d+)$/, post_embed.title)
    assert_equal post_embed&.url, "https://danbooru.donmai.us/posts/#{@sfw_post.id}"
    assert_equal post_embed.image&.url, @sfw_post.file_variant.url.to_s

    assert_match(POST_FOOTER_PATTERN, post_embed.footer&.text)
  end

  def test_animated_post
    embed = Discordrb::Webhooks::Embed.new
    @animated_post = @booru.posts.index(tags: "ugoira rating:g", limit: 1).first
    post_embed = @animated_post.embed(embed, @sfw_channel)

    assert_match(/^post #(\d+)$/, post_embed.title)
    assert_equal post_embed&.url, "https://danbooru.donmai.us/posts/#{@animated_post.id}"
    assert_equal post_embed.image&.url, @animated_post.preview_variant.url.to_s

    assert_match(POST_FOOTER_PATTERN, post_embed.footer&.text)
  end
end
