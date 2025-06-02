require "test_helper"

class EventEmbedTest < Minitest::Test
  include TestMocks

  def test_post_embed
    embeds = mock_event("post #1") => { embeds:, ** }
    assert_equal embeds.length, 1
    assert_equal embeds.first.title, "post #1"
  end

  def test_comment_embed
    embeds = mock_event("comment #1") => { embeds:, ** }
    assert_equal embeds.length, 1
    assert_equal embeds.first.title, "comment #1"
  end

  def test_forum_embed
    embeds = mock_event("forum #123") => { embeds:, ** }
    assert_equal embeds.length, 1
    assert_equal embeds.first.title, "tag count reset in /post?"
  end

  def test_topic_embed
    embeds = mock_event("topic #123") => { embeds:, ** }
    assert_equal embeds.length, 1
    assert_equal embeds.first.title, "Artist wiki - Note field"
  end

  def test_bur_embed
    embeds = mock_event("bur #123") => { embeds:, ** }
    assert_equal embeds.length, 1
    assert_equal embeds.first.title, "bulk update request #123"
  end

  def test_tag_embed
    embeds = mock_event("[[fate (series)]]") => { embeds:, ** }
    assert_equal embeds.length, 1
    assert_equal embeds.first.title, "fate (series)"
  end

  def test_postless_tag_embed
    embeds = mock_event("[[a]]") => { embeds:, ** }
    assert_equal embeds.length, 1
    assert_equal embeds.first.title, "a"
  end

  def test_tagless_wiki_embed
    embeds = mock_event("[[about:danbooru]]") => { embeds:, ** }
    assert_equal embeds.length, 1
    assert_equal embeds.first.title, "about:danbooru"
  end

  def test_search_embed
    embeds = mock_event("{{id:1,2 order:custom limit:2}}") => { embeds:, ** }
    assert_equal embeds.length, 2
    assert_equal embeds.first.title, "post #1"
    assert_equal embeds.second.title, "post #2"
  end

  def test_user_embed
    embeds = mock_event("user #1") => { embeds:, ** }
    assert_equal embeds.length, 1
    assert_equal embeds.first.title, "@albert"
  end

  def test_artist_embed
    msgs = mock_event("artist #123") => { msgs:, ** }
    assert_equal msgs.length, 1
    assert_equal msgs.first, "https://danbooru.donmai.us/artists/123"
  end

  def test_pixiv_embed
    msgs = mock_event("pixiv #123") => { msgs:, ** }
    assert_equal msgs.length, 1
    assert_equal msgs.first, "https://www.pixiv.net/artworks/123"
  end

  def test_github_issue_embed
    msgs = mock_event("issue #123") => { msgs:, ** }
    assert_equal msgs.length, 1
    assert_equal msgs.first, "https://github.com/danbooru/danbooru/issues/123"
  end

  def test_github_pull_embed
    msgs = mock_event("pull #123") => { msgs:, ** }
    assert_equal msgs.length, 1
    assert_equal msgs.first, "https://github.com/danbooru/danbooru/pull/123"
  end

  def test_multiple_embeds
    embeds = mock_event("post #1, post #2, post #3") => { embeds:, ** }
    assert_equal embeds.length, 3
    assert_equal embeds.first.title, "post #1"
    assert_equal embeds.second.title, "post #2"
    assert_equal embeds.third.title, "post #3"
  end

  def test_duplicate_embeds
    mock_event("post #1, comment #124, post #1, comment #123") => { embeds:, ** }
    assert_equal embeds.length, 3
    assert_equal embeds.first.title, "post #1"
    assert_equal embeds.second.title, "comment #124"
    assert_equal embeds.third.title, "comment #123"
  end

  def test_embed_in_backticks
    mock_event("` post #1 `") => { embeds:, ** }
    assert_equal embeds.length, 0
  end

  def test_embed_between_backticks
    mock_event("`test` post #1 `test`") => { embeds:, ** }
    assert_equal embeds.length, 1
  end

  def test_embed_in_code_block
    mock_event("```ruby\n post #1 ```") => { embeds:, ** }
    assert_equal embeds.length, 0
  end

  def test_embed_between_code_blocks
    mock_event("```ruby\n``` post #1 ```test```") => { embeds:, ** }
    assert_equal embeds.length, 1
  end
end
