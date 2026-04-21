require "active_support"
require "active_support/core_ext/object/try"
require "active_support/core_ext/string/inflections"
require "json"

class Danbooru
  # Wraps one API response and exposes parsed data + status helpers.
  class Response
    # @param response [HTTP::Response] Low-level HTTP response object.
    # @param resource_name [String] API resource name for model resolution.
    # @param api [Danbooru::Resource] Resource used to build model URLs.
    def initialize(response, resource_name:, api:)
      @response = response
      @resource_name = resource_name
      @api = api
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
      raise Danbooru::Exceptions::BadRequestError if bad_request?
      raise Danbooru::Exceptions::MaintenanceError if maintenance?
      raise Danbooru::Exceptions::DownbooruError if downbooru?
      raise Danbooru::Exceptions::TemporaryError if retry?
      raise Danbooru::Exceptions::AccessDeniedError if access_denied?
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

    # Parses JSON with a fallback payload for non-JSON error bodies.
    #
    # @return [Array, Hash]
    def parse_json
      JSON.parse(@response.body)
    rescue JSON::JSONError
      {
        success: false,
        message: "ERROR: non-JSON response.",
        code: @response.code,
        mime_type: @response.mime_type,
        body: @response.body.to_s,
      }
    end

    # Builds Fumimi model objects from parsed JSON.
    #
    # @return [Fumimi::Model, Array<Fumimi::Model>]
    def build_data
      return Fumimi::Model.new(@json, @resource_name, @api) if failed?

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
      model_class = "Fumimi::Model::#{@resource_name.singularize.camelize}".safe_constantize || Fumimi::Model
      model_class.new(item, @resource_name, @api)
    end

    # Returns true for the known timeout response payload.
    #
    # @return [Boolean]
    def timeout?
      @response.code == 500 && @data.try(:message) == "The database timed out running your query."
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
    def bad_request?
      @response.code >= 500 && ["ActiveModel::RangeError"].include?(@json["error"])
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

    # Returns true for HTTP statuses considered retriable.
    #
    # @return [Boolean]
    def retry?
      [429, 502, 503, 504].include?(@response.code)
    end
  end
end
