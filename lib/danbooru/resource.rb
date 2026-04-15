require "active_support"
require "active_support/core_ext/hash/keys"
require "retriable"

class Danbooru
  # Represents one Danbooru endpoint collection (for example `posts` or `tags`).
  class Resource
    include Enumerable

    class Error < StandardError; end
    UNSET = Object.new.freeze
    RETRY_OPTIONS = { tries: 1_000, max_interval: 15, max_elapsed_time: 90 }.freeze

    attr_reader :booru, :name, :url

    # @param name [String] Resource path name (usually pluralized, snake_case).
    # @param booru [Danbooru] Parent API client.
    # @param url [String, nil] Optional endpoint override.
    # @param default_params [Hash] Query params merged into GET-like calls.
    def initialize(name, booru, url: nil, default_params: {})
      @name = name
      @booru = booru
      @url = booru.url.to_s + "/" + (url || name)
      @by = :id
      @default_params = { limit: 1000 }.merge(default_params)
    end

    # Getter/setter-compatible fluent API for pagination strategy.
    # When called with no args, returns current value.
    # When called with a value, returns a cloned resource with the new setting.
    def by(value = UNSET)
      return @by if value.equal?(UNSET)

      resource = dup
      resource.by!(value)
    end

    # Mutating version of `by`.
    def by!(value = UNSET)
      return @by if value.equal?(UNSET)

      @by = value
      self
    end

    # Getter/setter-compatible fluent API for merged default query params.
    def default_params(value = UNSET)
      return @default_params if value.equal?(UNSET)

      resource = dup
      resource.default_params!(value)
    end

    # Mutating version of `default_params`.
    def default_params!(value = UNSET)
      return @default_params if value.equal?(UNSET)

      @default_params = if value.is_a?(Hash) && @default_params.is_a?(Hash)
                          @default_params.merge(value)
                        else
                          value
                        end
      self
    end

    # Sends a request with retry behavior and standardized response wrapping.
    #
    # @return [Danbooru::Response]
    def request(method, path = "/", params = {}, options = {})
      with_retry(options) do
        response = perform_request(method, path, params)
        response.raise_for_errors!
        response
      end
    end

    # Performs one HTTP call and wraps the low-level response.
    #
    # @return [Danbooru::Response]
    def perform_request(method, path, params)
      raw_response = booru.http.request(method, url + path, **params)
      Danbooru::Response.new(self, raw_response)
    end

    # GET /resource
    #
    # @return [Danbooru::Response]
    def index(params = {}, options = {})
      request(:get, "/", { params: default_params.merge(params) }, options)
    end

    # GET /resource/:id
    #
    # @return [Danbooru::Response]
    def show(id, params = {}, options = {})
      request(:get, "/#{id}", { params: default_params.merge(params) }, options)
    end

    # POST /resource
    #
    # @return [Danbooru::Response]
    def create(params = {}, options = {})
      request(:post, "/", { json: params }, options)
    end

    # PUT /resource/:id
    #
    # @return [Danbooru::Response]
    def update(id, params = {}, options = {})
      request(:put, "/#{id}", { json: params }, options)
    end

    # Adds `search[...]` prefixes to params and merges them into defaults.
    #
    # @return [Danbooru::Resource]
    def search(**params)
      params = params.transform_keys { |k| :"search[#{k}]" }
      default_params(params)
    end

    # Returns the first item by ascending id.
    def first
      index(limit: 1, page: "a0").first
    end

    # Returns the last item by descending id.
    def last
      index(limit: 1, page: "b100000000").first
    end

    # Iterates through endpoint results using either id-based or page-based pagination.
    def each(**params, &block)
      return enum_for(:each, **params) unless block_given?

      if by == :id
        each_by_id(**params, &block)
      else
        each_by_page(**params, &block)
      end
    end

    # Iterates using descending id windows (`page=b<ID>`).
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

    # Iterates using integer page numbers.
    def each_by_page(from: 1, to: 5_000, **params, &block)
      params = default_params.merge(params)

      from.upto(to - 1) do |n|
        items = index(**params, page: n)
        items.each(&block)

        return items if items.empty? || items.size < params[:limit]
      end
    end

    private

    # Runs a request in a retry loop and returns the last response on temporary failure.
    #
    # @return [Danbooru::Response]
    def with_retry(options)
      retry_options = RETRY_OPTIONS.merge(options)
      response = nil

      Retriable.retriable(on: Danbooru::Exceptions::TemporaryError, **retry_options) do
        response = yield
      end

      response
    rescue Danbooru::Exceptions::TemporaryError
      response
    end
  end
end
