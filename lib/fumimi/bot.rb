class Fumimi
  # The main bot class that drives the Discord bot.
  class Bot
    attr_reader :client_id, :token, :log, :http, :booru, :mod_booru, :booru_domains, :cache, :webserver, :censored_tags,
                :signoz_url, :signoz_api_key, :report_channel_id, :sockpuppet_channel_id, :report_monitor, :sockpuppet_monitor

    # Adapts the Discordrb logger to write through Fumimi's logger.
    DiscordLogStream = Struct.new(:log) do
      def puts(msg)
        level, thread, message = msg.to_s.match(/\A\[(\w+) : (\S*) @ [^\]]+\] (.*)/m)&.captures

        case level
        when "DEBUG", "OUT", "IN" then severity = Logger::DEBUG
        when "WARN", "RATELIMIT"  then severity = Logger::WARN
        when "ERROR"              then severity = Logger::ERROR
        else                           severity = Logger::INFO
        end

        log.add(severity) do
          tag = ["discord", thread].compact_blank.join("/")
          "[#{tag}] #{message}".strip
        end
      end

      def flush = nil
    end

    def initialize(
      client_id: nil,
      token: nil,
      host: nil,
      port: nil,
      booru_url: nil,
      booru_domains: nil,
      booru_user: nil,
      booru_api_key: nil,
      mod_user: nil,
      mod_api_key: nil,
      report_channel_id: nil,
      sockpuppet_channel_id: nil,
      signoz_url: nil,
      signoz_api_key: nil,
      censored_tags: nil,
      log: Fumimi.log,
      env: ENV
    )
      @client_id = client_id.presence || env["DISCORD_CLIENT_ID"]
      @token = token.presence || env["DISCORD_TOKEN"]
      @host = host.presence || env["FUMIMI_WEBSERVER_HOST"] || "0.0.0.0"
      @post = port.presence || env["FUMIMI_WEBSERVER_PORT"] || 3000
      @booru_url = booru_url.presence || env["BOORU_URL"] || "https://danbooru.donmai.us"
      @booru_domains = Array.wrap(booru_domains).presence || env["BOORU_DOMAINS"]&.split || [URI.parse(@booru_url).host]
      @booru_user = booru_user.presence || env["BOORU_USER"]
      @booru_api_key = booru_api_key.presence || env["BOORU_API_KEY"]
      @mod_user = mod_user.presence || env["BOORU_MOD_USER"] || @booru_user
      @mod_api_key = mod_api_key.presence || env["BOORU_MOD_API_KEY"] || @booru_api_key
      @report_channel_id = report_channel_id.presence || env["DISCORD_REPORT_CHANNEL_ID"]
      @sockpuppet_channel_id = sockpuppet_channel_id.presence || env["DISCORD_SOCKPUPPET_CHANNEL_ID"]
      @signoz_url = signoz_url.presence || env["SIGNOZ_URL"]
      @signoz_api_key = signoz_api_key.presence || env["SIGNOZ_API_KEY"]
      @censored_tags = censored_tags.presence || env["FUMIMI_CENSORED_TAGS"].to_s.split || []
      @log = log

      @http = HTTPClient.new.logger(log).timeout(30)
      @booru = Danbooru.new(url: @booru_url, user: @booru_user, api_key: @booru_api_key, http: http, model_builder: method(:build_model))
      @mod_booru = Danbooru.new(url: @booru_url, user: @mod_user, api_key: @mod_api_key, http: http, model_builder: method(:build_model))
      @cache = ActiveSupport::Cache::MemoryStore.new
      @webserver = Fumimi::Webserver.new(host: @host, port: @port, fumimi: self)

      @report_monitor = Fumimi::ReportMonitor.new(fumimi: self, booru: mod_booru)
      @sockpuppet_monitor = Fumimi::SockpuppetMonitor.new(fumimi: self, booru: mod_booru)

      Discordrb::LOGGER.streams = [DiscordLogStream.new(log)]
      Discordrb::LOGGER.mode = :debug
    end

    # @return [Discordrb::Server] The Discord server the bot is connected to. Assumes the bot is only in one server.
    def server
      @server ||= bot.servers.values.first
    end

    # @return [Discordrb::Channel, nil] The channel where user reports should be sent, or nil if not configured or found.
    def report_channel
      @report_channel ||= bot.channel(@report_channel_id.to_i) if @report_channel_id
    end

    # @return [Discordrb::Channel, nil] The channel where sockpuppet reports should be sent, or nil if not configured or found.
    def sockpuppet_channel
      @sockpuppet_channel ||= bot.channel(@sockpuppet_channel_id.to_i) if @sockpuppet_channel_id
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

    # @return [Fumimi::SlashCommandRegistry] The registry that manages slash command definitions and registration with Discord.
    def command_registry
      @command_registry ||= Fumimi::SlashCommandRegistry.new(fumimi: self)
    end

    def register_commands
      raise "DISCORD_CLIENT_ID must be set" if client_id.nil?
      raise "DISCORD_TOKEN must be set" if token.nil?

      command_registry.register_all
      Fumimi::MessageEvent.register_all(fumimi: self)

      bot.button { |event| Fumimi::Button.mark_handled(event) }
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
      bot.run(:async)
      register_commands

      report_monitor.start if report_channel.present?
      sockpuppet_monitor.start if sockpuppet_channel.present?

      loop do
        Fumimi.reload_changed_code!
        shutdown! if @initiate_shutdown
        sleep 1
      end
    end
  end
end
