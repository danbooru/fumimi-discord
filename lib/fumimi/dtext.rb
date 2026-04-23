# frozen_string_literal: true

require "dtext"
require "nokogiri"

class Fumimi::DText
  CUTOFF_MESSAGE = "***[...text was too long and has been cut off]***"

  # Converts DText markup into a Discord-safe markdown string.
  #
  # @param dtext [String] raw DText input
  # @param max_lines [Integer] maximum number of lines to keep
  # @param max_characters [Integer] maximum total character budget across kept lines
  # @param wiki_page [Boolean] whether wiki-specific collapsing should run
  # @return [String] converted markdown output
  def self.dtext_to_markdown(dtext, max_lines: 30, max_characters: 1500, wiki_page: false)
    return "" unless dtext.strip.present?

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
    text = text.gsub(/([^\n])\n\n(`![^`]+`)/, "\\1\n\\2")
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
    source_lines = text.split("\n").grep_v(/^\[Expand .*?\]$/)
    lines = []
    index = 0

    while index < source_lines.length
      current_line = source_lines[index]

      if current_line.match?(/^\s*\*\s/)
        list_lines = []
        while index < source_lines.length && source_lines[index].match?(/^\s*\*\s/)
          list_lines << source_lines[index]
          index += 1
        end

        append_result = append_collapsed_list_summary!(lines, collapsed_list_summary(list_lines))
        next_line = source_lines[index]
        if append_result == :attached_to_heading && next_line&.strip&.present? && !next_line.match?(/^\*\*.*\*\*$/)
          lines << ""
        end
      else
        lines << current_line
        index += 1
      end
    end

    lines.join("\n").gsub(/\n{3,}/, "\n\n").strip
  end

  # Recursively converts parsed HTML nodes into markdown text.
  #
  # @param html [Nokogiri::XML::Node]
  # @return [String]
  def self.html_to_markdown(html)
    children = html.children
    children.each_with_index.map do |node, index|
      node_to_markdown(node, next_node: children[index + 1])
    end.join
  end

  # Converts a single parsed HTML node into markdown text.
  #
  # @param node [Nokogiri::XML::Node]
  # @param next_node [Nokogiri::XML::Node, nil]
  # @return [String]
  def self.node_to_markdown(node, next_node: nil)
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
      node.attr("class") == "spoiler" ? "||#{html_to_markdown(node)}||" : html_to_markdown(node)

    when "details"
      summary = node.css("summary").first
      "[Expand \"#{sanitize_text(summary&.text.to_s)}\"]\n\n"

    when "media-embed"
      "`!#{node.attr("data-type")} ##{node.attr("data-id")}`\n"

    when "media-gallery"
      gallery = transform_media_gallery(node)
      next_node&.name == "p" ? "#{gallery}\n" : gallery

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
  end

  # Renders a media gallery as a bullet list of embed items.
  #
  # @param node [Nokogiri::XML::Node]
  # @return [String]
  def self.transform_media_gallery(node)
    node.element_children.map do |entry|
      label = render_children_text(entry.children).join.strip
      "* `!#{entry.attr("data-type")} ##{entry.attr("data-id")}`#{": #{label}" unless label.empty?}"
    end.join("\n") + "\n"
  end

  # Renders a <ul> node as an indented markdown bullet list. Nested <ul> elements
  # are recursed with increased indentation.
  #
  # @param node [Nokogiri::XML::Node]
  # @param indent [Integer]
  # @return [String]
  def self.transform_list(node, indent: 0)
    lines = node.element_children.flat_map do |child|
      case child.name
      when "li"
        li_text = child.children
                       .reject { |c| c.name == "ul" }
                       .then { |children| render_children_text(children) }
                       .join.strip
        ["#{'  ' * indent}* #{li_text}"]
      when "ul"
        [transform_list(child, indent: indent + 1).rstrip]
      else
        []
      end
    end

    "#{lines.join("\n")}\n"
  end

  # Appends a collapsed list summary to the closest previous heading line, or as a
  # new line if no heading is available.
  #
  # @param lines [Array<String>]
  # @param summary [String]
  # @return [Symbol] append result (:attached_to_heading, :appended_as_line, :no_target)
  def self.append_collapsed_list_summary!(lines, summary)
    i = lines.size - 1
    blank_count = 0
    while i >= 0 && lines[i].strip.empty?
      blank_count += 1
      i -= 1
    end

    if i >= 0 && lines[i].match?(/^\*\*.*\*\*$/)
      lines[i] += " (#{summary})"
      :attached_to_heading
    elsif i >= 0
      blank_count.times { lines.pop }
      lines << "(#{summary})"
      :appended_as_line
    else
      :no_target
    end
  end

  # Builds a compact summary string for a list block based on plain lines and
  # embedded media markers.
  #
  # @param list_lines [Array<String>]
  # @return [String]
  def self.collapsed_list_summary(list_lines)
    media_counts = Hash.new(0)
    media_line_count = 0

    list_lines.each do |line|
      media_types = line.scan(/`!([a-z_]+) #\d+`/).flatten
      media_line_count += 1 unless media_types.empty?
      media_types.each { |type| media_counts[type] += 1 }
    end

    plain_line_count = list_lines.length - media_line_count
    parts = []
    parts << "#{plain_line_count} #{plain_line_count == 1 ? 'line' : 'lines'}" if plain_line_count.positive?
    media_counts.each do |type, count|
      label = count == 1 ? type : "#{type}s"
      parts << "#{count} #{label}"
    end
    "#{parts.join(', ')} collapsed"
  end

  # Renders mixed text/element child nodes into plain markdown fragments.
  #
  # @param children [Array<Nokogiri::XML::Node>]
  # @return [Array<String>]
  def self.render_children_text(children)
    children.map { |child| child.text? ? sanitize_text(child.text) : html_to_markdown(child) }
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
