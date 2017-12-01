require "active_support"
require "active_support/core_ext/object/to_query"
require "rest-client"
require "json"

require "danbooru/model"

class Danbooru
  class Resource < RestClient::Resource
    class Error < StandardError; end
    attr_accessor :booru, :factory

    def factory
      @factory ||= Danbooru::Model
    end

    def default_params
      @default_params ||= { limit: 1000 }
    end

    def with(params)
      default_params.merge!(params)
      self
    end

    def search(params = {})
      params = params.transform_keys { |k| "search[#{k}]" }
      index(params)
    end

    def index(params = {})
      params = default_params.merge(params)
      params = "?" + params.to_query
      resp = self[params].get

      data = JSON.parse(resp.body)
      if data.is_a?(Array)
        data.map { |hash| factory.new(booru, hash) }
      elsif data.is_a?(Hash)
        factory.new(booru, data)
      else
        raise NotImplementedError
      end
    end

    def show(id)
      resp = self[id].get
      hash = JSON.parse(resp.body)
      factory.new(booru, hash)
    end

    def update!(id, **params)
      resp = self[id].put(params)

      if resp.code == 200
        hash = JSON.parse(resp.body)
        factory.new(booru, hash)
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
