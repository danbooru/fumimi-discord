class Fumimi
  # The main bot class that drives the Discord bot.
  class Bot
    include Fumimi::ExceptionHandler

    attr_reader :server_id, :client_id, :token, :log, :http, :booru, :booru_domains, :cache, :webserver, :censored_tags,
                :report_channel_name, :signoz_url, :signoz_api_key

    # Adapts the Discordrb logger to write through Fumimi's logger.
    DiscordLogStream = Struct.new(:log) do
      def puts(msg)
        level, thread, message = msg.to_s.match(/\A\[(\w+) : (\S+) @ [^\]]+\] (.*)/m)&.captures

        case level
        when "DEBUG", "OUT", "IN" then severity = Logger::DEBUG
        when "WARN", "RATELIMIT"  then severity = Logger::WARN
        when "ERROR"              then severity = Logger::ERROR
        else                           severity = Logger::INFO
        end

        log.add(severity) { "[discord/#{thread}] #{message}".strip }
      end

      def flush = nil
    end

    def initialize(
      server_id: nil,
      client_id: nil,
      token: nil,
      host: nil,
      port: nil,
      booru_url: nil,
      booru_domains: nil,
      booru_user: nil,
      booru_api_key: nil,
      reports_user: nil,
      reports_api_key: nil,
      report_channel_name: nil,
      signoz_url: nil,
      signoz_api_key: nil,
      censored_tags: nil,
      log: Fumimi.log,
      env: ENV
    )
      @server_id = server_id.presence&.to_i || env["DISCORD_SERVER_ID"]&.to_i
      @client_id = client_id.presence || env["DISCORD_CLIENT_ID"]
      @token = token.presence || env["DISCORD_TOKEN"]
      @host = host.presence || env["FUMIMI_WEBSERVER_HOST"] || "0.0.0.0"
      @post = port.presence || env["FUMIMI_WEBSERVER_PORT"] || 3000
      @booru_url = booru_url.presence || env["BOORU_URL"] || "https://danbooru.donmai.us"
      @booru_domains = Array.wrap(booru_domains).presence || env["BOORU_DOMAINS"]&.split || [URI.parse(@booru_url).host]
      @booru_user = booru_user.presence || env["BOORU_USER"]
      @booru_api_key = booru_api_key.presence || env["BOORU_API_KEY"]
      @reports_user = reports_user.presence || env["BOORU_REPORTS_USER"] || @booru_user
      @reports_api_key = reports_api_key.presence || env["BOORU_REPORTS_API_KEY"] || @booru_api_key
      @report_channel_name = report_channel_name.presence || env["DISCORD_REPORT_CHANNEL_NAME"] || "user-reports"
      @signoz_url = signoz_url.presence || env["SIGNOZ_URL"]
      @signoz_api_key = signoz_api_key.presence || env["SIGNOZ_API_KEY"]
      @censored_tags = censored_tags.presence || env["FUMIMI_CENSORED_TAGS"].to_s.split || []
      @log = log

      @http = HTTPClient.new.logger(log).timeout(30)
      @booru = Danbooru.new(url: @booru_url, user: @booru_user, api_key: @booru_api_key, http: http, model_builder: method(:build_model))
      @cache = ActiveSupport::Cache::MemoryStore.new
      @webserver = Fumimi::Webserver.new(host: @host, port: @port, fumimi: self)

      Discordrb::LOGGER.streams = [DiscordLogStream.new(log)]
      Discordrb::LOGGER.mode = :debug
    end

    def server
      bot.servers.fetch(@server_id)
    end

    def channels
      server.channels.index_by(&:name)
    end

    def shutdown!
      log.info("Shutting down...")
      bot.stop
      exit(0)
    end

    def bot
      @bot ||= Discordrb::Commands::CommandBot.new(
        name: "Robot Maid Fumimi",
        client_id: client_id,
        token: token,
        prefix: "/",
      )
    end

    def register_commands
      raise "DISCORD_SERVER_ID must be set" if server_id.nil?
      raise "DISCORD_CLIENT_ID must be set" if client_id.nil?
      raise "DISCORD_TOKEN must be set" if token.nil?

      Fumimi::SlashCommand.register_all(fumimi: self)
      Fumimi::Event.register_all(fumimi: self)

      bot.button { |event| Fumimi::Button.mark_handled(event) }
    end

    def monitor_reports
      return unless [@reports_user, @reports_api_key].all?

      report_booru = Danbooru.new(
        url: booru.url,
        user: @reports_user,
        api_key: @reports_api_key,
        http: http,
        model_builder: ->(booru: nil, **kwargs) { build_model(booru: report_booru, **kwargs) },
      )

      report_monitor = Fumimi::ReportMonitor.new(fumimi: self, booru: report_booru)
      report_monitor.start
    end

    # Used by the Danbooru API client to build Fumimi::Model instances.
    #
    # @param resource_name [String] The model name (e.g. "post", "user", "comment", "wiki_page", etc).
    # @param attributes [Hash] The attributes for the model.
    # @param booru [Danbooru] The Danbooru API client.
    # @return [Fumimi::Model] The constructed model instance
    def build_model(resource_name:, attributes:, booru: self.booru)
      klass = "Fumimi::Model::#{resource_name.singularize.camelize}".safe_constantize || Fumimi::Model
      klass.new(resource_name:, attributes:, booru:, fumimi: self)
    end

    def run
      log.info("Starting bot...")

      %w[INT TERM].each do |signal|
        trap signal do
          warn "SIG#{signal} received, initiating shutdown..." # Can't use logger inside a signal handler
          @initiate_shutdown = true
        end
      end

      webserver.start
      register_commands
      bot.run(:async)

      monitor_reports

      loop do
        Fumimi.reload_changed_code!
        shutdown! if @initiate_shutdown
        sleep 1
      end
    end
  end
end
