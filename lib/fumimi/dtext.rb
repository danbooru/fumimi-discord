require "dtext"
require "nokogiri"

class Fumimi::DText # rubocop:disable Metrics/ClassLength
  CUTOFF_MESSAGE = "***[...text was too long and has been cut off]***"

  # Converts DText markup into a Discord-safe markdown string.
  #
  # @param dtext [String] raw DText input
  # @param max_lines [Integer] maximum number of lines to keep
  # @param max_characters [Integer] maximum total character budget across kept lines
  # @param wiki_page [Boolean] whether wiki-specific collapsing should run
  # @return [String] converted markdown output
  def self.dtext_to_markdown(dtext, max_lines: 30, max_characters: 1500, wiki_page: false)
    html = Nokogiri::HTML5.fragment(DText.parse(dtext), max_tree_depth: -1)
    transformed = normalize_markdown(html_to_markdown(html))
    transformed = collapse_for_wiki_page(transformed) if wiki_page

    apply_truncation(transformed, max_lines:, max_characters:)
  end

  # Normalizes spacing in markdown text.
  #
  # @param text [String]
  # @return [String]
  def self.normalize_markdown(text)
    text = text.gsub(/[ \t]+\n/, "\n")
    text = text.gsub(/\n{3,}/, "\n\n")
    text.strip
  end

  # Applies line and character limits to text.
  #
  # @param text [String]
  # @param max_lines [Integer]
  # @param max_characters [Integer]
  # @return [String] truncated text, with cutoff message appended when limits are exceeded
  def self.apply_truncation(text, max_lines:, max_characters:)
    source_lines = text.split("\n")
    was_truncated = source_lines.length > max_lines

    found_characters = 0
    lines = []

    source_lines.first(max_lines).each do |line|
      break if found_characters > max_characters

      found_characters += line.length
      lines << line
      if found_characters > max_characters
        was_truncated = true
        break
      end
    end

    text = lines.join("\n")
    return text unless was_truncated

    "#{text}\n#{CUTOFF_MESSAGE}"
  end

  # Converts expanded wiki sections into compact form.
  #
  # @param text [String]
  # @return [String]
  def self.collapse_for_wiki_page(text)
    text = text.gsub(/^\[Expand .*?\]$/, "")
    lines = []
    in_list = false
    list_ended_without_blank = false

    text.split("\n").each do |line|
      if line.match?(/^\s*\*\s/)
        unless in_list
          append_collapsed_list_suffix!(lines)
          in_list = true
          list_ended_without_blank = false
        end
        next
      end

      # We're transitioning from list to non-list
      if in_list
        list_ended_without_blank = lines.last && lines.last.strip.empty? ? false : true
      end

      in_list = false

      # If the last line isn't empty and we just ended a list without a blank line,
      # and the current line is not a heading, add a blank line
      if list_ended_without_blank && line.strip.present? && !line.match?(/^\*\*/)
        lines << ""
        list_ended_without_blank = false
      end

      lines << line
    end

    lines.join("\n").gsub(/\n{3,}/, "\n\n").strip
  end

  # Recursively converts parsed HTML nodes into markdown text.
  #
  # @param html [Nokogiri::XML::Node]
  # @return [String]
  def self.html_to_markdown(html) # rubocop:disable Metrics/CyclomaticComplexity,Metrics/PerceivedComplexity
    html.children.map do |node| # rubocop:disable Metrics/BlockLength
      case node.name
      when "h1", "h2", "h3", "h4", "h5", "h6"
        "**#{sanitize_text(node.text)}**\n"

      when "b", "strong"
        "**#{html_to_markdown(node).strip}**"

      when "i", "em"
        "*#{html_to_markdown(node).strip}*"

      when "s"
        "~~#{html_to_markdown(node).strip}~~"

      when "u"
        "__#{html_to_markdown(node).strip}__"

      when "code"
        "`#{node.text}`"

      when "p"
        if node.attr("class") == "tn"
          "-# #{sanitize_text(node.text)}\n\n"
        else
          "#{html_to_markdown(node).strip}\n\n"
        end

      when "blockquote"
        "`<quote>`\n\n"

      when "br"
        "\n"

      when "span"
        if node.attr("class") == "spoiler"
          "||#{html_to_markdown(node)}||"
        else
          html_to_markdown(node)
        end

      when "details"
        summary = node.css("summary").first
        "[Expand \"#{sanitize_text(summary&.text.to_s)}\"]\n\n"

      when "media-embed"
        "`!#{node.attr("data-type")} ##{node.attr("data-id")}`\n"

      when "media-gallery"
        transform_media_gallery(node)

      when "pre"
        "\n`<code>`\n\n"

      when "table"
        "`<table>`\n\n"

      when "ul"
        transform_list(node)

      when "a", "text"
        sanitize_text(node.text)

      else
        html_to_markdown(node)
      end
    end.join
  end

  # Renders a media gallery as a bullet list of embed items.
  #
  # @param node [Nokogiri::XML::Node]
  # @param opts [Hash]
  # @return [String]
  def self.transform_media_gallery(node, **opts)
    node.element_children.map do |entry|
      label = render_children_text(entry.children, **opts).join.strip
      "* `!#{entry.attr("data-type")} ##{entry.attr("data-id")}`#{": #{label}" unless label.empty?}"
    end.join("\n") + "\n"
  end

  # Renders a <ul> node as an indented markdown bullet list. Nested <ul> elements
  # are recursed with increased indentation.
  #
  # @param node [Nokogiri::XML::Node]
  # @param indent [Integer]
  # @param opts [Hash]
  # @return [String]
  def self.transform_list(node, indent: 0, **opts)
    lines = node.element_children.flat_map do |child|
      case child.name
      when "li"
        li_text = child.children
                       .reject { |c| c.name == "ul" }
                       .then { |children| render_children_text(children, **opts) }
                       .join.strip
        ["#{'  ' * indent}* #{li_text}"]
      when "ul"
        [transform_list(child, indent: indent + 1, **opts).rstrip]
      else
        []
      end
    end

    "#{lines.join("\n")}\n"
  end

  # Appends " (collapsed list)" to the closest previous heading line, or as a new line if no heading found.
  #
  # @param lines [Array<String>]
  # @return [void]
  def self.append_collapsed_list_suffix!(lines)
    i = lines.size - 1
    blank_count = 0
    while i >= 0 && lines[i].strip.empty?
      blank_count += 1
      i -= 1
    end

    # If we found a heading, mark it
    if i >= 0 && lines[i].match?(/^\*\*.*\*\*$/)
      return if lines[i].end_with?(" (collapsed list)")

      lines[i] += " (collapsed list)"
    elsif i >= 0
      # No heading found. Remove trailing blank lines and append (collapsed list) as new line
      blank_count.times { lines.pop }
      lines << "(collapsed list)"
    end
  end

  # Renders mixed text/element child nodes into plain markdown fragments.
  #
  # @param children [Array<Nokogiri::XML::Node>]
  # @param opts [Hash]
  # @return [Array<String>]
  def self.render_children_text(children, **opts)
    children.map { |child| child.text? ? sanitize_text(child.text) : html_to_markdown(child, **opts) }
  end

  # Normalizes plain text and escapes markdown-sensitive characters.
  #
  # @param text [String]
  # @return [String]
  def self.sanitize_text(text)
    text.to_s
        .gsub(/\s+/, " ")
        .gsub("_", "\\_")
        .gsub("*", "\\*")
        .gsub("~", "\\~")
        .gsub("#", "\\#")
  end
end
