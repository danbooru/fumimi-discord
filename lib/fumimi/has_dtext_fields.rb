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
        case node.name
        when "i"
          "*#{node.text.gsub("*", "*")}*"
        when "b"
          "**#{node.text.gsub("**", "**")}**"
        when "div"
          "||#{node.text}||" if node.attr("class") == "spoiler"
        when "blockquote"
          # no-op
          nil
        when "details"
          "[Expand \"#{node.css("summary").first.text}\"]"
        else
          node.text
        end
      end

      nodes = nodes.compact.map { |node| node.split("\n") }.flatten
      nodes = nodes.first(max_lines) if max_lines.present?
      puts nodes

      sanitize_for_discord(nodes.join("\n\n").gsub(/\n\n+/, "\n\n").strip)
    end

    def sanitize_for_discord(text)
      text = text.gsub("_", "\\_") # Escape underscores
      text = text.gsub("*", "\\*") # Escape asterisks
      text = text.gsub("~", "\\~") # Escape tildes
      text = text.gsub("`", "\\`") # Escape backticks
      text = "#{text[..3000]}\n**[...text was too long and has been cut off]**" if text.size > 3000
      text
    end
  end
end
