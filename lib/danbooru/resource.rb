class Danbooru
  # Represents one Danbooru endpoint collection (for example `posts` or `tags`).
  class Resource
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

    # Sends one API request and maps errors to Danbooru exceptions.
    #
    # @return [Danbooru::Response]
    def request(method, path = "/", params = {})
      raw_response = booru.http.request(method, @url + path, **params)
      response = Danbooru::Response.new(raw_response, resource_name: @name, booru: @booru)
      response.raise_for_errors!
      response
    rescue HTTPClient::TimeoutError
      raise Danbooru::Exceptions::TimeoutError
    end

    # Fetches a collection from GET /resource.
    #
    # @return [Danbooru::Response]
    def index(params = {})
      request(:get, "/", { params: @default_params.merge(params) })
    end

    # Fetches one object from GET /resource/:id.
    #
    # @return [Danbooru::Response]
    def show(id, params = {})
      request(:get, "/#{id}", { params: @default_params.merge(params) })
    end
  end
end
