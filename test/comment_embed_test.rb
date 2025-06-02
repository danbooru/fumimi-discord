require "test_helper"

class CommentEmbedTest < Minitest::Test
  COMMENT_FOOTER_PATTERN = /^\d{4}-\d{2}-\d{2} at \d{1,2}:\d{2} (?:AM|PM)$/

  def setup
    factory = {
      posts: Fumimi::Model::Post,
      tags: Fumimi::Model::Tag,
      comments: Fumimi::Model::Comment,
      forum_posts: Fumimi::Model::ForumPost,
      users: Fumimi::Model::User,
      wiki_pages: Fumimi::Model::WikiPage,
    }.with_indifferent_access

    @booru = Danbooru.new(factory: factory)
    @nsfw_comment = @booru.comments.show(67906) # rubocop:disable Style/NumericLiterals

    @sfw_channel = Minitest::Mock.new
    def @sfw_channel.nsfw?
      false
    end

    @nsfw_channel = Minitest::Mock.new
    def @nsfw_channel.nsfw?
      true
    end
  end

  def test_nsfw_post_comment_on_sfw_channel
    embed = Discordrb::Webhooks::Embed.new
    comment_embed = @nsfw_comment.embed(embed, @sfw_channel)

    assert_equal comment_embed.title, "comment #67906"
    assert_equal comment_embed.url, "https://danbooru.donmai.us/comments/67906"
    assert_nil comment_embed.thumbnail&.url
    assert_nil comment_embed.color
    assert_match(COMMENT_FOOTER_PATTERN, comment_embed.footer&.text)
  end

  def test_nsfw_post_comment_on_nsfw_channel
    embed = Discordrb::Webhooks::Embed.new
    comment_embed = @nsfw_comment.embed(embed, @nsfw_channel)

    assert_equal comment_embed.title, "comment #67906"
    assert_equal comment_embed.url, "https://danbooru.donmai.us/comments/67906"
    assert_equal @nsfw_comment.post.preview_variant.url.to_s, comment_embed.thumbnail&.url
    assert_nil comment_embed.color
    assert_match(COMMENT_FOOTER_PATTERN, comment_embed.footer&.text)
  end

  def test_sfw_post_comment_on_nsfw_channel
    embed = Discordrb::Webhooks::Embed.new
    @sfw_comment = @booru.comments.index(tags: "rating:general", limit: 1).first
    comment_embed = @sfw_comment.embed(embed, @sfw_channel)

    assert_equal comment_embed.title, "comment ##{@sfw_comment.id}"
    assert_equal comment_embed.url, "https://danbooru.donmai.us/comments/#{@sfw_comment.id}"
    assert_equal @sfw_comment.post.preview_variant.url.to_s, comment_embed.thumbnail&.url
    assert_nil comment_embed.color
    assert_match(COMMENT_FOOTER_PATTERN, comment_embed.footer&.text)
  end

  def test_post_comment_from_animated_post
    embed = Discordrb::Webhooks::Embed.new
    @comment = @booru.comments.index(tags: "rating:general ugoira", limit: 1).first
    comment_embed = @comment.embed(embed, @sfw_channel)

    assert_equal comment_embed.title, "comment ##{@comment.id}"
    assert_equal comment_embed.url, "https://danbooru.donmai.us/comments/#{@comment.id}"
    assert_equal @comment.post.preview_variant.url.to_s, comment_embed.thumbnail&.url
    assert_nil comment_embed.color
    assert_match(COMMENT_FOOTER_PATTERN, comment_embed.footer&.text)
  end
end
