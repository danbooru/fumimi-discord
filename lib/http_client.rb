require "http"

# Small wrapper around the `http` gem that centralizes request setup,
# execution timing, and debug logging.
class HTTPClient
  # @param base [String] Base URL used by all requests.
  # @param user [String] Optional basic auth username.
  # @param pass [String] Optional basic auth password.
  # @param signoz_api_key [String, nil] Optional SigNoz API key header.
  # @param log [Logger] Logger instance for debug output.
  def initialize(base:, user: "", pass: "", signoz_api_key: nil, log: Logger.new(nil))
    @base = base.to_s.strip
    @user = user.to_s.strip
    @pass = pass.to_s.strip
    @signoz_api_key = signoz_api_key
    @log = log

    @connection = build_connection
  end

  %i[get put post delete].each do |method|
    define_method(method) do |url, **options|
      request(method, url, **options)
    end
  end

  # Executes an HTTP request and emits one debug log line with timing metadata.
  #
  # @param method [Symbol] HTTP method (`:get`, `:post`, `:put`, `:delete`).
  # @param path [String] Resource path beginning with `/`.
  # @param options [Hash] Request options forwarded to the http gem.
  # @return [HTTP::Response]
  def request(method, path, **options)
    response, duration = timed_request(method, path, **options)
    log_response(response, method, duration)
    response
  end

  private

  # Builds the configured `HTTP::Client` instance.
  #
  # @return [HTTP::Client]
  def build_connection
    connection = HTTP::Client.new
    connection = connection.basic_auth(user: @user, pass: @pass) unless @user.empty? || @pass.empty?
    connection = connection.accept("application/json")
    connection = connection.use(:auto_inflate).headers("Accept-Encoding": "gzip")
    connection = connection.headers("SIGNOZ-API-KEY": @signoz_api_key) unless @signoz_api_key.to_s.empty?
    connection = connection.follow
    connection = connection.nodelay
    connection = connection.persistent(@base)
    connection
  end

  # Sends one request and returns both response and wall-clock duration.
  #
  # @return [Array<(HTTP::Response, Float)>]
  def timed_request(method, path, **options)
    start = Time.now.to_f
    response = @connection.request(method, path, **options).flush
    duration = Time.now.to_f - start
    [response, duration]
  end

  # Emits a debug log line for a request when a logger is configured.
  def log_response(response, method, duration)
    return unless @log

    @log.debug("http") do
      default_log_message(response, method, duration)
    end
  end

  # Default unified HTTP log formatter used by all callers.
  #
  # @return [String]
  def default_log_message(response, method, duration)
    runtime_ms = (response.headers["X-Runtime"]&.to_f || 0) * 1000
    total_ms = duration * 1000
    "time=#{runtime_ms.to_i}ms total=#{total_ms.to_i}ms code=#{response.code} method=#{method.upcase} url=#{response.uri}"
  end
end
