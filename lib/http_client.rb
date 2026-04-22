require "http"

# Small wrapper around the `http` gem that centralizes request setup,
# execution timing, and debug logging.
class HTTPClient
  attr_writer :client

  delegate_missing_to :client

  # @param base [String] Base URL used by all requests.
  # @param user [String] Optional basic auth username.
  # @param pass [String] Optional basic auth password.
  # @param log [Logger] Logger instance for debug output.
  def initialize(base:, user: "", pass: "", log: Logger.new(nil))
    @base = base.to_s.strip
    @user = user.to_s.strip
    @pass = pass.to_s.strip
    @log = log
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

  # Builds the configured `HTTP::Client` instance.
  #
  # @return [HTTP::Client]
  def client
    @client ||= begin
      http = HTTP.persistent(@base)
      http = http.accept("application/json")
      http = http.use(:auto_inflate).headers("Accept-Encoding": "gzip")
      http = http.follow
      http = http.nodelay
      http = http.basic_auth(user: @user, pass: @pass) unless @user.empty? || @pass.empty?
      http
    end
  end

  private

  # Sends one request and returns both response and wall-clock duration.
  #
  # @return [Array<(HTTP::Response, Float)>]
  def timed_request(method, path, **options)
    start = Time.now.to_f
    response = client.request(method, path, **options).flush
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

    format(
      "code=%<code>-3s method=%<method>-6s time=%<time>-7s total=%<total>-7s url=%<url>s",
      code: response.code,
      method: method.upcase,
      time: "#{runtime_ms.to_i}ms",
      total: "#{total_ms.to_i}ms",
      url: response.uri
    )
  end
end
