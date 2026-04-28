class Danbooru
  # Wraps one API response and exposes parsed data + status helpers.
  class Response
    attr_reader :data, :response, :json

    # @param response [HTTPClient::Response] Low-level HTTP response object.
    # @param resource_name [String] API resource name for model resolution.
    # @param booru [Danbooru] API client used to build model URLs.
    def initialize(response, resource_name:, booru:)
      @response = response
      @resource_name = resource_name
      @booru = booru
      @json = parse_json
      @data = build_data
    end

    # Returns raw parsed JSON from the HTTP body.
    #
    # @return [Array, Hash]
    def as_json(_options = nil)
      @json
    end

    # Returns true when HTTP status code is 4xx/5xx.
    #
    # @return [Boolean]
    def failed?
      @response.code >= 400
    end

    # Returns true when HTTP status code is below 400.
    #
    # @return [Boolean]
    def succeeded?
      !failed?
    end

    # Raises the mapped Danbooru exception for known failures.
    #
    # @return [void]
    def raise_for_errors!
      raise Danbooru::Exceptions::TimeoutError if timeout?
      raise Danbooru::Exceptions::BadRequestError if bad_range_request?
      raise Danbooru::Exceptions::AccessDeniedError if access_denied?

      raise Danbooru::Exceptions::NotFoundError if not_found?

      raise Danbooru::Exceptions::DanbooruError, (@json["message"].presence || @json["error"].presence) if bad_parsable_request?

      raise Danbooru::Exceptions::MaintenanceError if maintenance?
      raise Danbooru::Exceptions::DownbooruError if downbooru?
    end

    # Delegates unknown methods to the parsed model payload.
    def method_missing(method_name, *args, &block)
      return @data.public_send(method_name, *args, &block) if @data.respond_to?(method_name)

      super
    end

    # Matches method_missing behavior for reflection helpers.
    def respond_to_missing?(method_name, include_private = false)
      @data.respond_to?(method_name, include_private) || super
    end

    private

    # Parses JSON or return an empty json.
    #
    # @return [Array, Hash]
    def parse_json
      JSON.parse(@response.body)
    rescue JSON::JSONError
      {}
    end

    # Builds model objects from parsed JSON.
    #
    # @return [Fumimi::Model, Array<Fumimi::Model>]
    def build_data
      return @booru.build_model(attributes: @json, resource_name: @resource_name) if failed?

      if @json.is_a?(Array)
        @json.map { |item| build_item(item) }
      elsif @json.is_a?(Hash)
        build_item(@json)
      else
        raise "Unrecognized response type (#{@json.class})"
      end
    end

    # Builds one model instance from a response object.
    #
    # @param item [Hash]
    # @return [Fumimi::Model]
    def build_item(item)
      @booru.build_model(attributes: item, resource_name: @resource_name)
    end

    # Returns true for the known timeout response payload.
    #
    # @return [Boolean]
    def timeout?
      @response.code == 500 && @json["message"] == "The database timed out running your query."
    end

    # Returns true when the maintenance banner appears.
    #
    # @return [Boolean]
    def maintenance?
      @response.code == 503 && @response.body.to_s.include?("<h1>Danbooru is down for maintenance.</h1>")
    end

    # Returns true for known bad-range server errors.
    #
    # @return [Boolean]
    def bad_range_request?
      @response.code >= 500 && ["ActiveModel::RangeError"].include?(@json["error"])
    end

    # Returns true if the server returned ActiveRecord::RecordNotFound
    #
    # @return [Boolean]
    def not_found?
      @response.code == 404 && ["ActiveRecord::RecordNotFound"].include?(@json["error"])
    end

    # Returns true for any response that has a json payload.
    #
    # @return [Boolean]
    def bad_parsable_request?
      failed? && @json["error"].present?
    end

    # Returns true when the site is generally unavailable.
    #
    # @return [Boolean]
    def downbooru?
      @response.code >= 500
    end

    # @return [Boolean] True if the API key is missing or invalid, or if the user lacks permissions for the endpoint.
    def access_denied?
      @response.code.in?([401, 403])
    end
  end
end
