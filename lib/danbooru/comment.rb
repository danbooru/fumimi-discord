require "danbooru/model"
require "danbooru/has_dtext_fields"

class Danbooru
  class Comment < Danbooru::Model
    include HasDTextFields

    def embed_footer
      timestamp = "#{created_at.strftime("%F")} at #{created_at.strftime("%l:%M %p")}"
      Discordrb::Webhooks::EmbedFooter.new(text: timestamp)
    end
  end
end
