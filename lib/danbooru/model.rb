require "addressable/uri"
require "ostruct"

class Danbooru
  class Model < OpenStruct
    attr_reader :booru

    def initialize(booru, attributes)
      @booru = booru

      attributes = attributes.map do |attr, value|
        value =
          case attr
          when "created_at", "updated_at", "last_commented_at", "last_comment_bumped_at", "last_noted_at"
            Time.parse(value) rescue nil
          when /_url$/
            Addressable::URI.parse(value)
          else
            value
          end
        [attr, value]
      end.to_h

      super(attributes)
    end

    def embed_footer
      timestamp = "#{created_at.strftime("%F")} at #{created_at.strftime("%l:%M %p")}"
      Discordrb::Webhooks::EmbedFooter.new(text: timestamp)
    end

    def to_json
      to_h.to_json
    end
  end
end
