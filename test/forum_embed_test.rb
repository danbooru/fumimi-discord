require "test_helper"

class ForumEmbedTest < Minitest::Test
  include TestMocks

  FORUM_POST_FOOTER_PATTERN = /^\d{4}-\d{2}-\d{2} at \d{1,2}:\d{2} (?:AM|PM)$/

  def setup
    @booru = setup_booru
    @forum_post = @booru.forum_posts.index(limit: 1).first
    @forum_creator = @booru.users.index(name: @forum_post.creator.name)

    @forum_post_banned = @booru.forum_posts.show(358_594)

    @channel = Minitest::Mock.new
  end

  def test_embed_forum_post
    embed = Discordrb::Webhooks::Embed.new
    forum_post_embed = @forum_post.embed(embed, @channel)

    assert_equal forum_post_embed.title, @forum_post.topic.title
    assert_equal forum_post_embed.url, "https://danbooru.donmai.us/forum_posts/#{@forum_post.id}"
    assert_nil forum_post_embed.image
    assert_nil forum_post_embed.color
    assert_equal forum_post_embed&.author&.name, "@#{@forum_post.creator.name}"
    assert_equal forum_post_embed&.author&.url, "https://danbooru.donmai.us/users/#{@forum_creator.id}"
    assert_match(FORUM_POST_FOOTER_PATTERN, forum_post_embed.footer&.text)
  end

  def test_banned_forum_post
    embed = Discordrb::Webhooks::Embed.new
    forum_post_embed = @forum_post_banned.embed(embed, @channel)
    # strikethrough is not supported for author names
    assert_equal forum_post_embed&.author&.name, "@#{@forum_post_banned.creator.name}"
  end
end
