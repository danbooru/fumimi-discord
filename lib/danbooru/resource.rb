require "active_support"
require "active_support/core_ext/hash/keys"
require "retriable"

require "danbooru/fluent"

class Danbooru
  class Resource
    include Enumerable
    extend Fluent

    class Error < StandardError; end

    attr_reader :booru, :name, :url, :default_options

    attr_fluent :by, :default_params

    def initialize(name, booru, url: nil, default_params: {}, default_options: {})
      @name = name
      @booru = booru
      @url = booru.url.to_s + "/" + (url || name)
      @by = :id
      @default_params = { limit: 1000 }.merge(default_params)
      @default_options = { tries: 1_000, max_interval: 15, max_elapsed_time: 90 }.merge(default_options)
    end

    def request(method, path = "/", params = {}, options = {})
      options = default_options.merge(options)
      resp = nil

      Retriable.retriable(on: Danbooru::Response::TemporaryError, **options) do
        resp = booru.http.request(method, url + path, **params)
        resp = Danbooru::Response.new(self, resp)

        raise Danbooru::Response::TimeoutError if resp.timeout?
        raise Danbooru::Response::MaintenanceError if resp.maintenance?
        raise Danbooru::Response::DownbooruError if resp.downbooru?

        raise Danbooru::Response::TemporaryError if resp.retry?
      end
    rescue Danbooru::Response::TemporaryError
      resp
    else
      resp
    end

    def index(params = {}, options = {})
      request(:get, "/", { params: default_params.merge(params) }, options)
    end

    def show(id, params = {}, options = {})
      request(:get, "/#{id}", { params: default_params.merge(params) }, options)
    end

    def create(params = {}, options = {})
      request(:post, "/", { json: params }, options)
    end

    def update(id, params = {}, options = {})
      request(:put, "/#{id}", { json: params }, options)
    end

    def search(**params)
      params = params.transform_keys { |k| :"search[#{k}]" }
      default_params(params)
    end

    def first
      index(limit: 1, page: "a0").first
    end

    def last
      index(limit: 1, page: "b100000000").first
    end

    def each(**params, &block)
      return enum_for(:each, **params) unless block_given?

      if by == :id
        each_by_id(**params, &block)
      else
        each_by_page(**params, &block)
      end
    end

    def each_by_id(from: 0, to: 100_000_000, **params, &block)
      params = default_params.merge(params)
      n = to

      loop do
        params[:limit] = (n - from).clamp(0, params[:limit])
        return [] if params[:limit] == 0

        items = index(**params, page: "b#{n}")
        items.select! { |item| item.id >= from && item.id < to }
        items.each(&block)

        return items if items.empty? || items.size < params[:limit]

        n = items.last.id
      end
    end

    def each_by_page(from: 1, to: 5_000, **params, &block)
      params = default_params.merge(params)

      from.upto(to - 1) do |n|
        items = index(**params, page: n)
        items.each(&block)

        return items if items.empty? || items.size < params[:limit]
      end
    end
  end
end
