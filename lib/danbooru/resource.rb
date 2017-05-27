require "rest-client"
require "json"

require "danbooru/model"

class Danbooru
  class Resource < RestClient::Resource
    attr_accessor :factory

    def factory
      @factory ||= Danbooru::Model
    end

    def default_params
      @default_params ||= { limit: 1000 }
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

    def index(params = {})
      params = default_params.merge(params)
      params = "?" + params.to_query
      resp = self[params].get

      array = JSON.parse(resp.body)
      array.map { |hash| factory.new(hash) }
    end

    def show(id)
      resp = self[id].get
      hash = JSON.parse(resp.body)
      factory.new(hash)
    end

    def newest(since, limit = 50)
      items = index(limit: limit)
      items.select { |i| i.created_at > since }
    end

    def each(from: 0)
      return enum_for(:each) unless block_given?

      id = from
      loop do
        items = index(page: "a#{id}").reverse
        break if items.empty?

        items.each { |i| yield i }
        id = items.last.id
      end
    end
  end
end
