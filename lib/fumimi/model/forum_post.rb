require "fumimi/model"

class Fumimi::Model::ForumPost < Fumimi::Model
  delegate :hidden?, to: :topic

  def embed_title
    topic.title
  end

  def shortlink
    "forum ##{id}"
  end

  def embed_author
    { name: creator.at_name, url: creator.url }
  end

  def embed_description
    raise Fumimi::Exceptions::PermissionError if hidden?

    description = Fumimi::DText.dtext_to_markdown(body)
    description += bur_description if try(:bulk_update_request).present?
    description
  end

  def bur_description
    <<~EOS


      #{bulk_update_request.pretty_title}
      #{bulk_update_request.pretty_script}
      ```ansi
      Score: #{pretty_votes}```
    EOS
  end

  def pretty_votes
    vote_types = {
      1 => { tally: 0, color: "green", symbol: "+" },
      0 => { tally: 0, color: "yellow", symbol: "" },
      -1 => { tally: 0, color: "red", symbol: "-" },
    }.with_indifferent_access

    votes.each { |vote| vote_types[vote["score"]]["tally"] += 1 }

    vote_types.values.map do |vote|
      Fumimi::Colors.message_to_ansi(message: "#{vote["symbol"]}#{vote["tally"]}", color: vote["color"], format: "bold")
    end.join(" | ")
  end

  def embed_color
    return unless try(:bulk_update_request).present?

    case bulk_update_request.status
    when "approved" || "processing"
      Fumimi::Colors::GREEN
    when "pending"
      Fumimi::Colors::BLUE
    else
      Fumimi::Colors::RED
    end
  end
end
