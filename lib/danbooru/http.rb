require "active_support"
require "active_support/core_ext/object/try"
require "connection_pool"
require "http"

class Danbooru::HTTP
  def initialize(url, user: "", pass: "", connections: 10, timeout: 60, log: Logger.new(nil))
    @url, @user, @pass = url.to_s.strip, user.to_s.strip, pass.to_s.strip
    @connections, @timeout, @log = connections, timeout, log

    @pool = ConnectionPool.new(size: @connections, timeout: @timeout) do
      connect(@url, @user, @pass, @timeout)
    end
  end

  %i[get put post delete].each do |method|
    define_method(method) do |url, **options|
      request(method, url, **options)
    end
  end

  def request(method, url, **options)
    response, duration = time_request(method, url, **options)
    log_response(response, method, duration)

    response
  end

  private

  def connect(url, user = "", pass = "", timeout = 60)
    conn = HTTP::Client.new
    conn = conn.basic_auth(user: user, pass: pass) unless user.empty? || pass.empty?
    conn = conn.accept("application/json")
    # conn = conn.timeout(:global, read: timeout, write: timeout, connect: timeout)
    conn = conn.use(:auto_inflate).headers("Accept-Encoding": "gzip")
    conn = conn.follow
    conn = conn.nodelay
    conn = conn.persistent(url)
    conn
  end

  def time_request(method, url, **options)
    @pool.with do |conn|
      start = Time.now.to_f
      response = conn.request(method, url, **options).flush
      finish = Time.now.to_f

      duration = finish - start
      return response, duration
    end
  end

  def log_response(response, method, duration)
    @log.debug "http" do
      runtime = (response.headers["X-Runtime"].try(&:to_f) || 0) * 1000
      latency = ((duration * 1000) - runtime)
      socket = response.connection.instance_variable_get("@socket").socket
      ip = socket.local_address.inspect_sockaddr rescue nil
      fd = socket.fileno rescue nil

      stats = "time=%-6s lag=%-6s ip=%s fd=%s" % ["#{runtime.to_i}ms", "+#{latency.to_i}ms", ip, fd]
      "#{stats} code=#{response.code} method=#{method.upcase} url=#{response.uri}"
    end
  end
end
