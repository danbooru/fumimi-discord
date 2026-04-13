require "test_helper"

class ForumCommandTest < Minitest::Test
  include TestMocks

  FORUM_POST_FOOTER_PATTERN = /^\d{4}-\d{2}-\d{2} at \d{1,2}:\d{2} (?:AM|PM)$/

  def test_responds_to_command
    mock_slash_command("/forum", args: { limit: 2 }) => { reply_embeds:, ** }
    assert_equal 2, reply_embeds.length

    forum_post = reply_embeds[0]

    assert forum_post.title
    assert forum_post.description

    assert_match %r{^https://danbooru.donmai.us/forum_posts/\d+$}, forum_post.url
    assert_nil forum_post.image
    assert_nil forum_post.color
    assert forum_post.author.name
    assert_match %r{^https://danbooru.donmai.us/users/\d+$}, forum_post.author.url
    assert_match(FORUM_POST_FOOTER_PATTERN, forum_post.footer&.text)
  end

  def test_responds_to_command_filter
    string = "Daily Report (2022-07-13)"
    mock_slash_command("/forum", args: { limit: 1, contains: string, creator: "NNTBot" }) => { reply_embeds:, ** }
    assert_equal reply_embeds.length, 1
    assert reply_embeds[0].title == "New/Repopulated/Nuked Tag Report"
    assert reply_embeds[0].author.name = "NNTBot"
    assert reply_embeds[0].author.url = "https://danbooru.donmai.us/users/865894"
  end
end
