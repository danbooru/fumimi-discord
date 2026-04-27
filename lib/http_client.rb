require "faraday"
require "faraday/follow_redirects"
require "faraday/net_http_persistent"
require "faraday/retry"

# The internal library used to make HTTP requests. A wrapper around Faraday that adds a chainable API for configuration.
class HTTPClient
  class Error < StandardError; end
  class TimeoutError < Error; end
  class ConnectionError < Error; end

  # Wraps a Faraday::Response instead of exposing it directly, to abstract away the underlying HTTP library.
  Response = Struct.new(:response) do
    def code    = response.status
    def status  = response.status
    def headers = response.headers
    def body    = response.body
  end

  protected attr_writer :base_url, :timeout, :headers, :middlewares, :connection

  # @return [HTTPClient] A new HTTP client with default configuration.
  def initialize
    @base_url = nil
    @headers = {}
    @middlewares = []
    @timeout = nil
  end

  # @param log [Logger] Logger instance for logging requests.
  # @return [HTTPClient] A new client with the given logger set.
  def logger(log)
    use(:logger, log, headers: false)
  end

  # @param url [String] Base URL used by all requests.
  # @return [HTTPClient] A new client with the given base URL set.
  def base_url(url)
    with_copy(:base_url, url.to_s.strip)
  end

  # @param user [String] Basic auth username.
  # @param pass [String] Basic auth password.
  # @return [HTTPClient] A new client with basic auth credentials set.
  def auth(user, pass)
    return self if user.blank? || pass.blank?

    use(:authorization, :basic, user.to_s.strip, pass.to_s.strip)
  end

  # @param value [Numeric] HTTP request timeout in seconds.
  # @return [HTTPClient] A new client with the timeout set.
  def timeout(value)
    with_copy(:timeout, value)
  end

  # @param new_headers [Hash] The headers to add to the existing default headers.
  # @return [HTTPClient] A new client with the given headers set.
  def headers(new_headers)
    with_copy(:headers, @headers.merge(new_headers).transform_keys(&:to_s))
  end

  # @param middleware [Symbol] The middleware to add to the stack.
  # @return [HTTPClient] A new client with the given middleware added to the stack.
  def use(middleware, *args, **kwargs)
    middleware = lookup_middleware(middleware) if middleware.is_a?(Symbol)
    with_copy(:middlewares, @middlewares + [[middleware, args, kwargs]])
  end

  def get(url, **options) = request(:get, url, **options)
  def put(url, **options) = request(:put, url, **options)
  def post(url, **options) = request(:post, url, **options)
  def delete(url, **options) = request(:delete, url, **options)

  # @param method [Symbol] HTTP method.
  # @param url [String] The URL to request.
  # @param params [Hash, nil] The GET/HEAD query string parameters.
  # @param body [String, Hash, nil] The PUT/POST body.
  # @return [HTTPClient::Response] The HTTP response.
  def request(method, url, params: nil, body: nil)
    response = connection.send(method, url, params || body)
    Response.new(response)
  rescue Faraday::TimeoutError
    raise TimeoutError
  rescue Faraday::ConnectionFailed
    raise ConnectionError
  end

  private

  def connection
    @connection ||= Faraday.new do |f|
      @headers.each { |k, v| f.headers[k] = v }
      @middlewares.each { |name, args, kwargs| f.use(name, *args, **kwargs) }

      f.url_prefix = @base_url
      f.options.timeout = @timeout if @timeout
      f.adapter :net_http_persistent
    end
  end

  # @param name [Symbol] The Faraday middleware name.
  # @return [Class] The resolved middleware class.
  def lookup_middleware(name)
    [Faraday::Request, Faraday::Response, Faraday::Middleware].each do |registry|
      return registry.lookup_middleware(name)
    rescue Faraday::Error
      next
    end
  end

  # @param attribute [Symbol] The attribute to change.
  # @param value [Object] The new value for the attribute.
  # @return [HTTPClient] A new HTTP client, used for chaining configuration methods.
  def with_copy(attribute, value)
    copy = dup
    copy.send("#{attribute}=", value)
    copy.connection = nil
    copy
  end
end
