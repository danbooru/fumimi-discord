require "test_helper"

class TagEventTest < Minitest::Test
  include TestMocks

  def test_tag
    embeds = mock_event("[[academic_test]]", nsfw_channel: false) => { embeds:, ** }

    assert_equal 1, embeds.length
    tag = embeds.first

    assert_match(/^post #\d+$/, tag.author.name)
    assert_match %r{^https://danbooru.donmai.us/posts/\d+$}, tag.author.url

    assert_nil tag.color
    assert_match %r{^https://cdn.donmai.us/original/}, tag.image.url
    assert_nil tag.footer
    assert_nil tag.timestamp

    assert_match(/^-# Category: General | Post Count: \d+$/, tag.description.split("\n").first)

    assert_equal tag.title, "academic test"
    assert_equal tag.url, "https://danbooru.donmai.us/wiki_pages/59934"
  end

  def test_tag_alias
    embeds = mock_event("[[jjk]]", nsfw_channel: false) => { embeds:, ** }
    assert_equal 1, embeds.length
    tag = embeds.first

    lines = tag.description.split("\n")
    assert_match(/-# Category: Copyright | Post Count: \d+.$/, lines.first.strip)
    assert_equal "-# Aliased from `jjk`.", lines.second.strip
  end

  def test_tag_wildcard
    embeds = mock_event("[[*hand_on*]]", nsfw_channel: false) => { embeds:, ** }
    assert_equal 1, embeds.length
    tag = embeds.first

    lines = tag.description.split("\n")
    assert_match(/-# Category: General | Post Count: \d+.$/, lines.first.strip)
    assert_equal "-# First result for `*hand_on*`.", lines.second.strip
  end

  def test_deprecated_tag
    embeds = mock_event("[[test]]", nsfw_channel: false) => { embeds:, ** }
    assert_equal 1, embeds.length
    tag = embeds.first

    assert_equal tag.description, <<~EOF.strip
      -# Category: General | Post Count: 0
      -# This tag has been deprecated.

      See academic test.
    EOF
  end

  def test_embed_wiki_with_no_tag
    embeds = mock_event("[[about:danbooru]]", nsfw_channel: false) => { embeds:, ** }
    assert_equal 1, embeds.length
    tag = embeds.first

    assert_equal tag.description.split("\n").last.strip, "***[...text was too long and has been cut off]***"
    assert_equal tag.title, "about:danbooru"
    assert_equal tag.url, "https://danbooru.donmai.us/wiki_pages/120511"
    assert_nil tag.image
    assert_nil tag.author
  end

  def test_embed_tag_with_no_wiki
    random_string = (0...15).map { rand(65..90).chr }.join
    embeds = mock_event("[[#{random_string}]]", nsfw_channel: false) => { embeds:, ** }
    assert_equal 1, embeds.length
    tag = embeds.first

    assert_match(/There is currently no wiki page for the tag `/, tag.description)
    assert_equal random_string, tag.title
    assert_match %r{https://danbooru.donmai.us/posts\?tags=}, tag.url
    assert_nil tag.image
    assert_nil tag.author
  end

  def test_nsfw_tag_on_nsfw_channel
    embeds = mock_event("[[sex]]", nsfw_channel: true) => { embeds:, ** }

    assert_equal 1, embeds.length
    tag = embeds.first

    assert_match(/^post #\d+$/, tag.author.name)
    assert_match %r{^https://danbooru.donmai.us/posts/\d+$}, tag.author.url
    assert_match %r{^https://cdn.donmai.us/original/}, tag.image.url
  end

  def test_nsfw_tag_on_sfw_channel
    embeds = mock_event("[[sex]]", nsfw_channel: false) => { embeds:, ** }

    assert_equal 1, embeds.length
    tag = embeds.first

    assert_nil tag.image
    assert_nil tag.author
  end

  def test_pool_by_number
    embeds = mock_event("[[pool:8948]]") => { embeds:, ** }

    assert_equal 1, embeds.length
    pool = embeds.first

    assert_equal "https://danbooru.donmai.us/pools/8948", pool.url
    assert_equal "Pool #8948: Original - Pop Team Epic (bkub)", pool.title

    assert_equal Fumimi::Colors::PURPLE, pool.color

    assert_match(/Start Reading Here/, pool.description)
    assert_match(/-# Category: Series | Post Count: \d+\n/, pool.description)
  end

  def test_pool_by_name
    embeds = mock_event("[[pool:perfect feet]]") => { embeds:, ** }

    assert_equal 1, embeds.length
    pool = embeds.first

    assert_equal "https://danbooru.donmai.us/pools/109", pool.url
    assert_equal "Pool #109: Perfect Feet", pool.title

    assert_equal Fumimi::Colors::BLUE, pool.color

    refute_match(/Start Reading Here/, pool.description)
    assert_match(/-# Category: Collection | Post Count: \d+\n/, pool.description)
  end

  def test_user_by_name
    embeds = mock_event("[[user:albert]]") => { embeds:, ** }
    assert_equal 1, embeds.length
    user = embeds.first

    assert_equal "@albert", user.title
    assert_equal "https://danbooru.donmai.us/users/1", user.url

    fields = user.fields
    assert_equal "Admin", fields[0].value
    assert_match(/\d+/, fields[3].value)
  end
end
