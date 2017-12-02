require "ostruct"

class Danbooru
  class Model < OpenStruct
    attr_reader :api, :booru

    def initialize(api, attributes)
      @api = api
      @booru = api.booru

      attributes = cast_attributes(attributes)
      super(attributes)
    end

    def update!(**params)
      api.update!(id, **params)
    end

    def url
      "#{api.url}/#{id}"
    end

    def shortlink
      name = self.class.name.demodulize.underscore.tr("_", " ")
      "#{name} ##{id}"
    end

    def to_json
      to_h.to_json
    end

    protected

    def cast_attributes(attributes)
      attributes.map do |name, value|
        [name, cast_attribute(name, value)]
      end.to_h
    end

    def cast_attribute(name, value)
      case name
      when /_at$/
        Time.parse(value) rescue nil
      when /_url$/
        Addressable::URI.parse(value)
      else
        value
      end
    end
  end
end
