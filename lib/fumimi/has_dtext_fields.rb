require "dtext"
require "nokogiri"

class Fumimi
  module HasDTextFields
    def html_body
      DText.parse(body)
    end

    def pretty_body(max_lines: nil)
      nodes = Nokogiri::HTML.fragment(html_body)

      nodes = nodes.children.map do |node|
        node.inner_html = node.inner_html.gsub("<br>", "\n")
        parse_node(node)
      end

      nodes = nodes.compact.map { |node| node.split("\n") }.flatten
      if max_lines.present?
        was_cut_off = nodes.size > max_lines
        nodes = nodes.first(max_lines)
      end
      nodes = nodes.join("\n\n").gsub(/\n\n+/, "\n\n").gsub(/\n+-/, "\n-").strip

      sanitized = sanitize_for_discord(nodes)
      sanitized += "\n**[...text was too long and has been cut off]**" if was_cut_off

      sanitized
    end

    def parse_node(node) # rubocop:disable Metrics/CyclomaticComplexity
      case node.name
      when "i"
        "*#{node.text.gsub("*", "*")}*"
      when "b"
        "**#{node.text.gsub("**", "**")}**"
      when "details" # [Expand] blocks
        "[Expand \"#{node.css("summary").first.text}\"]"
      when "div"
        "||#{node.text}||" if node.attr("class") == "spoiler"
      when "blockquote"
        # no-op
        nil
      when "pre" # code block - they look just too ugly in embeds
        "`<code block>`"
      when "ul" # lists
        node.css("li").map { |li| "- #{li.text.strip}" }.join("\n")
      when "media-gallery" # embeds
        node.css("media-embed").map do |e|
          "- #{e.text.strip} (!#{e.attr("data-type")} ##{e.attr("data-id")})"
        end.join("\n")
      when "table"
        "`<table block>`"
      else
        node.text
      end
    end

    def sanitize_for_discord(text)
      text = text.gsub("_", "\\_") # Escape underscores
      text = text.gsub("*", "\\*") # Escape asterisks
      text = text.gsub("~", "\\~") # Escape tildes
      text = "#{text[..3000]}\n**[...text was too long and has been cut off]**" if text.size > 3000
      text
    end
  end
end
