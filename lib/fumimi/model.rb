module Fumimi::Model
  def embed_footer
    timestamp = "#{created_at.strftime("%F")} at #{created_at.strftime("%l:%M %p")}"
    Discordrb::Webhooks::EmbedFooter.new(text: timestamp)
  end

  def booru
    api.booru
  end
end
