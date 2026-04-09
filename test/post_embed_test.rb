require "test_helper"

class PostEmbedTest < Minitest::Test
  include TestMocks

  POST_FOOTER_PATTERN = /\d+⇧ \d+♥ | Rating: [GSQE] | \d+x\d+ (\d+.\d+ \d+ \w+) | \d{4}-\d{2}-\d{2}/

  def setup
    @booru = setup_booru
    @nsfw_post = @booru.posts.show(1)

    @sfw_channel = CHANNEL_MOCK.new(name: "#test", is_nsfw: false)
    @nsfw_channel = CHANNEL_MOCK.new(name: "#test", is_nsfw: true)
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

  def test_flagged_post_has_red_border
    @flagged_post = @booru.posts.index(tags: "is:flagged", limit: 1).first
    post_embed = @flagged_post.embed(Discordrb::Webhooks::Embed.new, @sfw_channel)

    assert_equal Fumimi::Colors::RED, post_embed.color
  end

  def test_pending_post_has_blue_border
    @pending_post = @booru.posts.index(tags: "is:pending -parent:any -is:flagged rating:general", limit: 1).first
    post_embed = @pending_post.embed(Discordrb::Webhooks::Embed.new, @sfw_channel)

    assert_equal Fumimi::Colors::BLUE, post_embed.color
  end

  def test_post_with_active_children_has_green_border
    @parent_post = @booru.posts.index(tags: "child:any -parent:any -is:flagged rating:general", limit: 1).first
    post_embed = @parent_post.embed(Discordrb::Webhooks::Embed.new, @nsfw_channel)

    assert @parent_post.has_active_children, "Expected post #{@parent_post.id} to have active children"
    assert_equal Fumimi::Colors::GREEN, post_embed.color
  end

  def test_deleted_post_has_white_border
    @deleted_post = @booru.posts.index(tags: "status:deleted rating:e -parent:any -is:flagged", limit: 1).first
    post_embed = @deleted_post.embed(Discordrb::Webhooks::Embed.new, @sfw_channel)

    assert_equal Fumimi::Colors::WHITE, post_embed.color
  end
end
