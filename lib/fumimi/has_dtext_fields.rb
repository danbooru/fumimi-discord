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
      nodes = nodes.first(max_lines) if max_lines.present?

      sanitize_for_discord(nodes.join("\n\n").gsub(/\n\n+/, "\n\n").gsub(/\n+-/, "\n-").strip)
    end

    def parse_node(node) # rubocop:disable Metrics/CyclomaticComplexity
      case node.name
      when "i"
        "*#{node.text.gsub("*", "*")}*"
      when "b"
        "**#{node.text.gsub("**", "**")}**"
      when "details"
        "[Expand \"#{node.css("summary").first.text}\"]"
      when "div"
        "||#{node.text}||" if node.attr("class") == "spoiler"
      when "blockquote"
        # no-op
        nil
      when "pre" # code block
        "`<code block>`"
      when "ul"
        node.css("li").map { |li| "- #{li.text}" }.join("\n")
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
