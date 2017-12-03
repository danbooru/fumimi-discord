require "active_support"
require "active_support/core_ext/object/to_query"
require "rest-client"
require "json"

require "danbooru/model"

class Danbooru
  class Resource < RestClient::Resource
    class Error < StandardError; end
    attr_accessor :booru, :factory

    def initialize(url, options = {})
      @booru = options[:booru]
      @factory = options[:factory] || Danbooru::Model
      super(url, options)
    end

    def default_params
      { limit: 1000 }
    end

    def search(params = {})
      params = params.transform_keys { |k| "search[#{k}]" }
      index(params)
    end

    def index(params = {})
      params = default_params.merge(params)
      resp = self.get(params: params)

      data = JSON.parse(resp.body)
      if data.is_a?(Array)
        data.map { |hash| factory.new(self, hash) }
      elsif data.is_a?(Hash)
        factory.new(self, data)
      else
        raise NotImplementedError
      end
    end

    def show(id)
      resp = self[id].get
      hash = JSON.parse(resp.body)
      factory.new(self, hash)
    end

    def update!(id, **params)
      resp = self[id].put(params)

      if resp.code == 200
        hash = JSON.parse(resp.body)
        factory.new(self, hash)
      else
        raise Danbooru::Resource::Error.new(resp)
      end
    end

    def newest(since, limit = 50)
      items = index(limit: limit)
      items.select { |i| i.created_at > since }
    end

    def each(**params)
      return enum_for(:each, **params) unless block_given?

      id = 0
      loop do
        items = index(**params, page: "a#{id}").reverse
        break if items.empty?

        items.each { |i| yield i }
        id = items.last.id
      end
    end

    def export(file = STDOUT)
      each do |model|
        file.puts model.to_json
      end
    end
  end
end
