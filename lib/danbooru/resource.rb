require "retriable"

class Danbooru
  # Represents one Danbooru endpoint collection (for example `posts` or `tags`).
  class Resource
    RETRY_OPTIONS = { tries: 1_000, max_interval: 15, max_elapsed_time: 90 }.freeze

    attr_reader :booru

    # @param name [String] Resource path name (usually pluralized, snake_case).
    # @param booru [Danbooru] Parent API client.
    # @param url [String, nil] Optional endpoint override.
    # @param default_params [Hash] Query params merged into GET-like calls.
    def initialize(name, booru, url: nil, default_params: {})
      @name = name
      @booru = booru
      @url = booru.url.to_s + "/" + (url || name)
      @default_params = { limit: 1000 }.merge(default_params)
    end

    # Sends one API request with retry handling and error mapping.
    #
    # @return [Danbooru::Response]
    def request(method, path = "/", params = {}, options = {})
      retry_options = RETRY_OPTIONS.merge(options)
      response = nil

      Retriable.retriable(on: [Danbooru::Exceptions::TemporaryError, HTTP::SocketReadError, HTTP::ConnectionError], **retry_options) do
        raw_response = booru.http.timeout(20).request(method, @url + path, **params)
        response = Danbooru::Response.new(raw_response, resource_name: @name, booru: @booru)
        response.raise_for_errors!
      end

      response
    rescue Danbooru::Exceptions::TemporaryError
      response
    rescue HTTP::TimeoutError
      raise Danbooru::Exceptions::TimeoutError
    end

    # Fetches a collection from GET /resource.
    #
    # @return [Danbooru::Response]
    def index(params = {}, options = {})
      request(:get, "/", { params: @default_params.merge(params) }, options)
    end

    # Fetches one object from GET /resource/:id.
    #
    # @return [Danbooru::Response]
    def show(id, params = {}, options = {})
      request(:get, "/#{id}", { params: @default_params.merge(params) }, options)
    end
  end
end
