require "active_support"
require "active_support/core_ext/module/delegation"
require "active_support/core_ext/object/try"
require "pp"

class Danbooru
  # Wraps a low-level HTTP response and exposes parsed models + status helpers.
  class Response
    attr_reader :model, :resource, :response

    delegate_missing_to :model

    # @param resource [Danbooru::Resource]
    # @param response [HTTP::Response]
    def initialize(resource, response)
      @resource = resource
      @response = response
      @model = build_model
    end

    # Parses and memoizes response JSON.
    #
    # @return [Array, Hash]
    def json
      @json ||= JSON.parse(@response.body)
    rescue JSON::JSONError
      # On 404 errors, the body is "not found". On 503/504 errors (returned by Cloudflare), the body is HTML.
      @json ||= {
        success: false,
        message: "ERROR: non-JSON response.",
        code: @response.code,
        mime_type: @response.mime_type,
        body: @response.body.to_s,
      }
    end

    # Exposes raw parsed JSON representation.
    def as_json(options = nil)
      json
    end

    alias_method :inspect, :pretty_inspect
    def pretty_print(printer)
      printer.pp("#<#{self.class.name}:0x#{object_id.to_s(16)}>" => model)
    end

    # Resolves a model factory class for this resource.
    #
    # @return [Class]
    def factory
      "Fumimi::Model::#{resource.name.singularize.camelize}".safe_constantize || Fumimi::Model
    end

    # Builds either one model or a list of models from parsed JSON.
    #
    # @return [Fumimi::Model, Array<Fumimi::Model>]
    def build_model
      return Fumimi::Model.new(json, resource.name, resource) if failed?

      case json
      when Array
        json.map { |item| build_item(item) }
      when Hash
        build_item(json)
      else
        raise "Unrecognized response type (#{json.class})"
      end
    end

    # Builds one model item using the resolved factory.
    def build_item(item)
      factory.new(item, resource.name, resource)
    end

    # Returns a human-friendly error message for failed requests.
    #
    # @return [String, nil]
    def error
      return nil unless failed?

      "#{response.status}: #{message}"
    end

    # True if HTTP status is 4xx/5xx.
    def failed?
      response.code >= 400
    end

    # True if HTTP status is below 400.
    def succeeded?
      !failed?
    end

    # Raises the mapped domain exception for this response, if any.
    #
    # @raise [Danbooru::Exceptions::DanbooruError]
    def timeout?
      response.code == 500 && model.try(:message) == "The database timed out running your query."
    end

    def maintenance?
      response.code == 503 && (@response.body.to_s.include? "<h1>Danbooru is down for maintenance.</h1>")
    end

    def bad_request?
      response.code >= 500 && ["ActiveModel::RangeError"].include?(json["error"])
    end

    def downbooru?
      response.code >= 500
    end

    def retry?
      [429, 502, 503, 504].include?(response.code)
    end

    # Raises a specific Danbooru exception when the response indicates an error.
    #
    # @return [void]
    def raise_for_errors!
      raise Danbooru::Exceptions::TimeoutError if timeout?
      raise Danbooru::Exceptions::BadRequestError if bad_request?
      raise Danbooru::Exceptions::MaintenanceError if maintenance?
      raise Danbooru::Exceptions::DownbooruError if downbooru?
      raise Danbooru::Exceptions::TemporaryError if retry?
    end
  end
end
