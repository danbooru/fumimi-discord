require "test_helper"

class TagEmbedTest < Minitest::Test
  include TestMocks

  FORUM_POST_FOOTER_PATTERN = /^\d{4}-\d{2}-\d{2} at \d{1,2}:\d{2} (?:AM|PM)$/
  def setup
    @booru = setup_booru
    @channel = Minitest::Mock.new
  end

  def test_embed_tag
    embed = Discordrb::Webhooks::Embed.new
    tag = @booru.tags.search(name_or_alias_matches: "academic_test").first
    tag_embed = tag.embed(embed, @channel, searched_tag: "test")

    lines = tag_embed.description.lines

    assert_match(/Category: General | Post Count: \d+/, lines.first)
    assert_equal "-# Aliased from `test`.", lines.second.strip

    assert_equal tag_embed.title, "academic test"
    assert_equal tag_embed.url, "https://danbooru.donmai.us/wiki_pages/59934"
    assert_match(%r{cdn.donmai.us/original/}, tag_embed.image.url)
    assert_match(/^post #\d+$/, tag_embed.author.name)
    assert_match(%r{danbooru.donmai.us/posts/\d+}, tag_embed.author.url)
  end

  def test_embed_wiki_with_no_tag
    embed = Discordrb::Webhooks::Embed.new
    wiki = @booru.wiki_pages.search(title_normalize: "about:danbooru").first
    wiki_embed = wiki.embed(embed, @channel)

    assert wiki_embed.description
    assert_equal wiki_embed.title, "about:danbooru"
    assert_equal wiki_embed.url, "https://danbooru.donmai.us/wiki_pages/120511"
    assert_nil wiki_embed.image
    assert_nil wiki_embed.author
  end

  def test_embed_tag_with_no_wiki
    embed = Discordrb::Webhooks::Embed.new
    tag = @booru.tags.search(has_wiki_page: false).first
    tag_embed = tag.embed(embed, @channel, searched_tag: tag.name)

    assert_match(/There is currently no wiki page for the tag `/, tag_embed.description)
    assert_equal tag_embed.title, tag.name.tr("_", " ")
    assert_match %r{https://danbooru.donmai.us/posts\?tags=}, tag_embed.url
    assert_nil tag_embed.image
    assert_nil tag_embed.author
  end

  def test_embed_deprecated_tag
  end
end
