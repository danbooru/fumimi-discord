require "test_helper"

class DtextToMarkdownTest < ApplicationTest
  PARAGRAPH_DTEXT = <<~EOF.chomp
    "Lorem ipsum dolor sit amet":https://danbooru.donmai/forum_posts/123,
    [[consectetur_adipiscing]] elit,
    {{sed do eiusmod}}
    [[tempor incididunt|Tempor Incididunt]]
    [b]ut labore[/b] [spoiler]et dolore[/spoiler] [i]magna aliqua[/i]. [s]Ut enim[/s] [b][i]ad minim veniam[/i][/b],
    [u]quis nostrud[/u] [code]exercitation_ullamco *** # laboris[/code] _nisi_ut *aliquip* ~ex~ ea commodo consequat.
    # Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur.
    Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum.
  EOF

  PARAGRAPH_MARKDOWN = <<~EOF.chomp
    Lorem ipsum dolor sit amet,
    consectetur\\_adipiscing elit,
    sed do eiusmod
    Tempor Incididunt
    **ut labore** ||et dolore|| *magna aliqua*. ~~Ut enim~~ ***ad minim veniam***,
    __quis nostrud__ `exercitation_ullamco *** # laboris` \\_nisi\\_ut \\*aliquip\\* \\~ex\\~ ea commodo consequat.
    \\# Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur.
    Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum.
  EOF

  EXPAND_DTEXT = <<~EOF.chomp
    [expand Lorem Ipsum]
    #{PARAGRAPH_DTEXT}
    #{PARAGRAPH_DTEXT}
    #{PARAGRAPH_DTEXT}
    #{PARAGRAPH_DTEXT}
    #{PARAGRAPH_DTEXT}
    #{PARAGRAPH_DTEXT}
    #{PARAGRAPH_DTEXT}
    #{PARAGRAPH_DTEXT}
    #{PARAGRAPH_DTEXT}
    #{PARAGRAPH_DTEXT}
    [/expand]
  EOF
  EXPAND_MARKDOWN = '[Expand "Lorem Ipsum"]'

  QUOTE_DTEXT = <<~EOF.chomp
    [quote]
    Lorem Ipsum said in topic #123:

    #{PARAGRAPH_DTEXT}
    [/quote]
  EOF
  QUOTE_MARKDOWN = "`<quote>`"

  TABLE_DTEXT = <<~EOF.chomp
    [table]
    [thead]
    [tr]
    [th]Feature[/th]
    [/tr]
    [/thead]
    [tbody]
    [tr]
    [td]✓[/td]
    [/tr]
    [/tbody]
    [/table]
  EOF
  TABLE_MARKDOWN = "`<table>`"

  LIST_WITH_HEADERS_DTEXT = <<~EOF.chomp
    h3. Header
    h4. Header1
    * list1
    * list2
    * list3
    h5. Header1.2
    ** list3.1
    *** list3.1.1
    h5. Header2
    * list4
    * list5
    * list6
    * list7
  EOF

  LIST_WITH_HEADERS_MARKDOWN = <<~EOF.chomp
    **Header**
    **Header1**
    * list1
    * list2
    * list3
    **Header1.2**
      * list3.1
        * list3.1.1
    **Header2**
    * list4
    * list5
    * list6
    * list7
  EOF

  LIST_WITH_HEADERS_MARKDOWN_COLLAPSED = <<~EOF.chomp
    **Header**
    **Header1** (3 lines collapsed)
    **Header1.2** (2 lines collapsed)
    **Header2** (4 lines collapsed)
  EOF

  CODE_BLOCK_DTEXT = <<~EOF.chomp
    ```
    Lorem_ipsum_dolor *sit amet, _consectetur *adipiscing elit
    ```
  EOF

  CODE_BLOCK_MARKDOWN = "`<code>`"

  TRANSLATION_NOTE_DTEXT = <<~EOF.chomp
    [tn]
    [[translation_note]]
    [/tn]
  EOF

  TRANSLATION_NOTE_MARKDOWN = "-# translation\\_note"

  MEDIA_EMBED_DTEXT = <<~EOF.chomp
    Consider this:
    !post #2647501
    This post is an embed.

    h4. Appearance
    * !post #2647501: Default
    * !post #2168021: [[no armor|Without Armor]]
    * !asset #2132774: With Crown and Cape
  EOF

  MEDIA_EMBED_MARKDOWN = <<~EOF.chomp
    Consider this:
    `!post #2647501`
    This post is an embed.

    **Appearance**
    * `!post #2647501`: Default
    * `!post #2168021`: Without Armor
    * `!asset #2132774`: With Crown and Cape
  EOF

  MEDIA_EMBED_MARKDOWN_COLLAPSED = <<~EOF.chomp
    Consider this:
    `!post #2647501`
    This post is an embed.

    **Appearance** (2 posts, 1 asset collapsed)
  EOF

  MULTIPLE_LISTS_DTEXT = <<~EOF.chomp
    Consider this:
    !post #2647501
    This post is an embed.

    h4. Appearance
    * !post #2647501: Default
    * !post #2168021: [[no armor|Without Armor]]
    * !asset #2132774: With Crown and Cape
    h4. Another List
    * one thing
    * !post #123
    * another thing
  EOF

  MULTIPLE_LISTS_MARKDOWN = <<~EOF.chomp
    Consider this:
    `!post #2647501`
    This post is an embed.

    **Appearance**
    * `!post #2647501`: Default
    * `!post #2168021`: Without Armor
    * `!asset #2132774`: With Crown and Cape
    **Another List**
    * one thing
    * `!post #123`
    * another thing
  EOF

  MULTIPLE_LISTS_MARKDOWN_COLLAPSED = <<~EOF.chomp
    Consider this:
    `!post #2647501`
    This post is an embed.

    **Appearance** (2 posts, 1 asset collapsed)
    **Another List** (2 lines, 1 post collapsed)
  EOF

  DTEXT_STRING = <<~EOF.chomp
    #{PARAGRAPH_DTEXT}

    #{TABLE_DTEXT}

    #{EXPAND_DTEXT}

    #{QUOTE_DTEXT}

    #{LIST_WITH_HEADERS_DTEXT}

    #{CODE_BLOCK_DTEXT}

    #{TRANSLATION_NOTE_DTEXT}

    #{MEDIA_EMBED_DTEXT}

    #{MULTIPLE_LISTS_DTEXT}
  EOF

  MARKDOWN_STRING = <<~EOF.chomp
    #{PARAGRAPH_MARKDOWN}

    #{TABLE_MARKDOWN}

    #{EXPAND_MARKDOWN}

    #{QUOTE_MARKDOWN}

    #{LIST_WITH_HEADERS_MARKDOWN}

    #{CODE_BLOCK_MARKDOWN}

    #{TRANSLATION_NOTE_MARKDOWN}

    #{MEDIA_EMBED_MARKDOWN}

    #{MULTIPLE_LISTS_MARKDOWN}
  EOF

  MARKDOWN_STRING_FOR_WIKI = <<~EOF.chomp
    #{PARAGRAPH_MARKDOWN}

    #{TABLE_MARKDOWN}

    #{QUOTE_MARKDOWN}

    #{LIST_WITH_HEADERS_MARKDOWN_COLLAPSED}

    #{CODE_BLOCK_MARKDOWN}

    #{TRANSLATION_NOTE_MARKDOWN}

    #{MEDIA_EMBED_MARKDOWN_COLLAPSED}

    #{MULTIPLE_LISTS_MARKDOWN_COLLAPSED}
  EOF

  def test_markdown_conversion_paragraph
    markdown = Fumimi::DText.dtext_to_markdown(PARAGRAPH_DTEXT, max_lines: 1000, max_characters: 10_000)
    assert_equal PARAGRAPH_MARKDOWN, markdown
  end

  def test_markdown_conversion_expand
    markdown = Fumimi::DText.dtext_to_markdown(EXPAND_DTEXT, max_lines: 1000, max_characters: 10_000)
    assert_equal EXPAND_MARKDOWN, markdown
  end

  def test_markdown_conversion_quote
    markdown = Fumimi::DText.dtext_to_markdown(QUOTE_DTEXT, max_lines: 1000, max_characters: 10_000)
    assert_equal QUOTE_MARKDOWN, markdown
  end

  def test_markdown_conversion_list_with_headers
    markdown = Fumimi::DText.dtext_to_markdown(LIST_WITH_HEADERS_DTEXT, max_lines: 1000, max_characters: 10_000)
    assert_equal LIST_WITH_HEADERS_MARKDOWN, markdown
  end

  def test_markdown_conversion_code_block
    markdown = Fumimi::DText.dtext_to_markdown(CODE_BLOCK_DTEXT, max_lines: 1000, max_characters: 10_000)
    assert_equal CODE_BLOCK_MARKDOWN, markdown
  end

  def test_markdown_conversion_translation_note
    markdown = Fumimi::DText.dtext_to_markdown(TRANSLATION_NOTE_DTEXT, max_lines: 1000, max_characters: 10_000)
    assert_equal TRANSLATION_NOTE_MARKDOWN, markdown
  end

  def test_markdown_conversion_full_string
    markdown = Fumimi::DText.dtext_to_markdown(DTEXT_STRING, max_lines: 1000, max_characters: 10_000)
    assert_equal MARKDOWN_STRING, markdown
  end

  def test_markdown_conversion_media_embed
    markdown = Fumimi::DText.dtext_to_markdown(MEDIA_EMBED_DTEXT, max_lines: 1000, max_characters: 10_000)
    assert_equal MEDIA_EMBED_MARKDOWN, markdown
  end

  def test_markdown_conversion_multiple_lists
    markdown = Fumimi::DText.dtext_to_markdown(MULTIPLE_LISTS_DTEXT, max_lines: 1000, max_characters: 10_000)
    assert_equal MULTIPLE_LISTS_MARKDOWN, markdown
  end

  def test_markdown_conversion_full_string_for_wiki
    markdown = Fumimi::DText.dtext_to_markdown(
      DTEXT_STRING,
      max_lines: 1000,
      max_characters: 10_000,
      wiki_page: true,
    )
    assert_equal MARKDOWN_STRING_FOR_WIKI, markdown
  end

  def test_markdown_conversion_respects_max_lines
    too_many_paragraphs_dtext = (1..20).map { |i| "Paragraph #{i}." }.join("\n\n")

    markdown = Fumimi::DText.dtext_to_markdown(
      too_many_paragraphs_dtext,
      max_lines: 10,
      max_characters: 1_000,
    )

    assert_includes markdown, "***[...text was too long and has been cut off]***"
    assert_includes markdown, "Paragraph 1."
    refute_includes markdown, "Paragraph 20."
  end

  def test_markdown_conversion_respects_max_characters
    long_paragraph_dtext = "a" * 1500

    markdown = Fumimi::DText.dtext_to_markdown(
      long_paragraph_dtext,
      max_lines: 10,
      max_characters: 1_000,
    )

    assert_includes markdown, "***[...text was too long and has been cut off]***"
    assert_operator markdown.length, :>, 1_000
  end

  def test_help_users_wiki
    dtext = File.read(File.expand_path("files/help_users_text.dtext", __dir__)).strip
    expected_markdown = File.read(File.expand_path("files/help_users_text.md", __dir__)).strip

    markdown = Fumimi::DText.dtext_to_markdown(dtext, max_lines: 20, wiki_page: true)

    assert_equal expected_markdown, markdown
  end

  def test_long_list
    dtext = File.read(File.expand_path("files/list_of_final_fantasy_characters.dtext", __dir__))

    markdown = Fumimi::DText.dtext_to_markdown(
      dtext,
      max_lines: 100,
      max_characters: 2_000,
      wiki_page: true,
    )

    assert_includes markdown, "See also"
    refute_includes markdown, "***[...text was too long and has been cut off]***"
  end
end
