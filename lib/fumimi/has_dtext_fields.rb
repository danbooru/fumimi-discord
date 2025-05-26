require "dtext"
require "nokogiri"

class Fumimi
  module HasDTextFields
    def html_body
      DText.parse(body)
    end

    def pretty_body
      nodes = Nokogiri::HTML.fragment(html_body)

      body = nodes.children.map do |node|
        node.inner_html = node.inner_html.gsub("<br>", "\n")
        case node.name
        when "i"
          "*#{node.text.gsub("*", "*")}*"
        when "b"
          "**#{node.text.gsub("**", "**")}**"
        when "div", "blockquote"
          # no-op
          nil
        else
          node.text
        end
      end.compact.join("\n\n")

      sanitize_for_discord(body)
    end

    def sanitize_for_discord(text)
      text = text.gsub("_", "\\_") # Escape underscores
      text = text.gsub("*", "\\*") # Escape asterisks
      text = text.gsub("~", "\\~") # Escape tildes
      text = text.gsub("`", "\\`") # Escape backticks
      text = text.gsub("||", "\\|\\|") # Escape vertical bars
      text
    end
  end
end
