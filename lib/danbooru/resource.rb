require "json"
require "ostruct"

require "addressable/uri"
require "rest-client"

class Danbooru
  class Resource < RestClient::Resource
    attr_accessor :type

    def type
      @type ||= OpenStruct
    end

    def default_params
      @default_params ||= { limit: 200 }
    end

    def with(params)
      resource = self.dup
      resource.default_params.merge!(params)
      resource
    end

    def search(params = {})
      params = params.transform_keys { |k| "search[#{k}]" }
      index(params)
    end

    def index(params)
      params = default_params.merge(params)
      params = "?" + params.to_query
      resp = self[params].get

      array = JSON.parse(resp.body)
      array.map { |hash| deserialize(hash) }
    end

    def show(id)
      resp = self[id].get
      hash = JSON.parse(resp.body)
      deserialize(hash)
    end

    def newest(since, limit = 50)
      items = index(limit: limit)
      items.select { |i| i.created_at >= since }
    end

    def deserialize(hash)
      hash = hash.map do |key, value|
        value =
          case key
          when "created_at", "updated_at", "last_commented_at", "last_comment_bumped_at", "last_noted_at"
            Time.parse(value) rescue nil
          when /_url$/
            Addressable::URI.parse(value)
          else
            value
          end
        [key, value]
      end.to_h

      type.new(hash)
    end
  end
end
