class Fumimi::Model::BulkUpdateRequest < Fumimi::Model
  # no embed, just embed the forum post instead so we can also get votes and argument

  def pretty_title
    "**[BUR ##{id}](#{url}) (#{status.titleize})**"
  end

  def pretty_script
    lines = normalized_script.split("\n")
    body = "```\n#{lines.first(10).join("\n")}```"
    body += "...and #{lines.size - 10} more lines." if lines.size > 10
    body
  end

  def normalized_script
    script.split("\n").map do |line|
      line.gsub(/^create implication/, "imply")
          .gsub(/^remove implication/, "unimply")
          .gsub(/^create alias/, "alias")
          .gsub(/^remove alias/, "unalias")
          .gsub(/^mass update/, "update")
    end.map(&:strip).compact.join("\n").gsub(" -> ", " → ")
  end

  # def pretty_status
  #   color = case status
  #           when "approved" || "processing"
  #             "green"
  #           when "pending"
  #             "blue"
  #           else
  #             "red"
  #           end
  #   Fumimi::Colors.message_to_ansi(message: status.titleize, color: color)
  # end
end
