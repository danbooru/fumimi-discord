require "active_support"
require "active_support/core_ext/module/delegation"
require "active_support/core_ext/object/try"
require "pp"

class Danbooru
  class Response
    class TemporaryError < StandardError; end
    class TimeoutError < StandardError; end
    class DownbooruError < StandardError; end

    attr_reader :model, :resource, :response

    delegate_missing_to :model

    def initialize(resource, response)
      @resource, @response = resource, response

      if failed?
        @model = Fumimi::Model.new(json, resource.name, resource)
      elsif json.is_a?(Array)
        @model = json.map { |item| factory.new(item, resource.name, resource) }
      elsif json.is_a?(Hash)
        @model = factory.new(json, resource.name, resource)
      else
        raise "Unrecognized response type (#{json.class})"
      end
    end

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

    def as_json(options = nil)
      json
    end

    alias_method :inspect, :pretty_inspect
    def pretty_print(printer)
      printer.pp("#<#{self.class.name}:0x#{object_id.to_s(16)}>" => model)
    end

    def factory
      name = resource.name
      resource.booru.factory[name] || "Fumimi::Model::#{name.singularize.camelize}".safe_constantize || Fumimi::Model
    end

    def error
      return nil unless failed?

      "#{response.status}: #{message}"
    end

    def failed?
      response.code >= 400
    end

    def succeeded?
      !failed?
    end

    def timeout?
      response.code == 500 && model.try(:message) == "The database timed out running your query."
    end

    def downbooru?
      response.code == 503 && (@response.body.to_s.include? "<h1>Danbooru is down for maintenance.</h1>")
    end

    def retry?
      [429, 502, 503, 504].include?(response.code)
    end
  end
end
