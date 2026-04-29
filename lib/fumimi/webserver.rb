# A webserver used to provide a /up endpoint for healthchecks.
class Fumimi
  class Webserver
    attr_reader :fumimi, :host, :port, :log

    # Wraps a Logger so that access log messages are formatted the same as other log messages.
    AccessLogger = Struct.new(:log) do
      def <<(msg) = log.info { msg.strip }
    end

    # @param fumimi [Fumimi::Bot] The Fumimi bot instance.
    # @param host [String] The address to bind the webserver to.
    # @param port [Integer] The port to bind the webserver to.
    def initialize(fumimi:, host: "localhost", port: 3000)
      @fumimi = fumimi
      @host = host
      @port = port
      @log = fumimi.log
      @app = nil
      @server = nil
    end

    # @return [Proc] The Rack application.
    def app
      @app ||= proc do |env|
        case env["PATH_INFO"]
        when "/up"
          status = fumimi.bot.connected? ? 200 : 503
          [status, {}, []]
        else
          [404, {}, []]
        end
      end
    end

    # @return [WEBrick::HTTPServer] The WEBrick server instance.
    def server
      @server ||= Rackup::Handler::WEBrick::Server.new(
        app,
        Host: host,
        Port: port,
        Logger: log,
        AccessLog: [[AccessLogger.new(log), WEBrick::AccessLog::COMBINED_LOG_FORMAT]],
      )
    end

    # Start the webserver if host and port are configured.
    #
    # @return [Thread] The thread running the webserver.
    def start
      Thread.new do
        next if host.blank? || port.blank?

        log.info("Starting webserver on #{host}:#{port}...")
        server.start
      end
    end
  end
end
