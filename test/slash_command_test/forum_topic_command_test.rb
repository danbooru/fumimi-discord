require "test_helper"

class ForumTopicCommandTest < Minitest::Test
  include TestMocks

  FORUM_POST_FOOTER_PATTERN = /^\d{4}-\d{2}-\d{2} at \d{1,2}:\d{2} (?:AM|PM)$/

  def test_find_results
    mock_slash_command("/topics", args: { limit: 2, creator: "nonamethanks" }) => { reply_embeds:, ** }
    assert_equal 2, reply_embeds.length

    forum_post = reply_embeds[0]

    assert forum_post.title
    assert forum_post.description

    assert_match %r{^https://danbooru.donmai.us/forum_posts/\d+$}, forum_post.url
    assert_nil forum_post.image
    assert forum_post.author.name
    assert_match %r{^https://danbooru.donmai.us/users/\d+$}, forum_post.author.url
    assert forum_post.timestamp
  end

  def test_error
    mock_slash_command("/topics", args: { limit: 1, creator: "~~~" }) => { reply_embeds:, ** }
    assert_equal reply_embeds.length, 1
    error = reply_embeds.first
    assert_equal error.title, "No results found."
    assert_equal error.description, "Fumimi tried really hard, but there were no results..."
  end
end
