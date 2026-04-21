require "test_helper"

class CommentCommandTest < ApplicationTest
  def test_find_results
    mock_slash_command("/comments", args: { limit: 1, creator: "nonamethanks" }) => { reply_embeds:, ** }
    assert_equal 1, reply_embeds.length

    comment = reply_embeds.first
    assert_equal reply_embeds.length, 1
    assert_match(/comment #\d+/, comment.title)
    assert_equal "@nonamethanks", comment.author.name
    assert_equal "https://danbooru.donmai.us/users/508240", comment.author.url
    assert comment.description
    assert_match(/Score: -?\d+/, comment.footer.text)
    assert comment.timestamp
  end

  def test_no_results
    mock_slash_command("/comments", args: { limit: 1, creator: "~~~" }) => { reply_embeds:, ** }
    assert_equal reply_embeds.length, 1
    error = reply_embeds.first
    assert_equal error.title, "No Results."
    assert_equal error.description, "Fumimi tried really hard, but there were no results..."
  end
end
