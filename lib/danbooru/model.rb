require "addressable/uri"
require "ostruct"

class Danbooru
  class Model < OpenStruct
    def initialize(attributes)
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
  end
end
