require "dtext"
require "nokogiri"

class Danbooru
  module HasDTextFields
    def html_body
      DText.parse(body)
    end

    def pretty_body
      nodes = Nokogiri::HTML.fragment(html_body)

      nodes.children.map do |node|
        case node.name
        when "i"
          "*#{node.text.gsub(/\*/, "\*")}*"
        when "b"
          "**#{node.text.gsub(/\*\*/, "\*\*")}**"
        when "div", "blockquote"
          # no-op
          nil
        else
          node.text
        end
      end.compact.take(2).join("\n\n")
    end
  end
end
