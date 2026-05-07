class Fumimi
  # Monitors /user_events for new sockpuppet accounts and posts them to the #sockpuppet-feed channel. A sockpuppet
  # account is detected when multiple accounts share the same session.
  class SockpuppetMonitor
    attr_reader :fumimi, :booru, :id

    delegate :start, :shutdown, :running?, to: :monitor
    delegate :cache, :log, :sockpuppet_channel, to: :fumimi

    # @param fumimi [Fumimi::Bot] Fumimi instance for accessing the bot and its configuration.
    # @param booru [Danbooru, nil] Booru client to use. Defaults to fumimi.mod_booru.
    # @param id [Integer, nil] Starting ID for the monitor. If nil, starts from the latest record.
    def initialize(fumimi:, booru: fumimi&.mod_booru, id: nil)
      @fumimi = fumimi
      @booru = booru
      @id = id
    end

    # @return [Danbooru::Monitor] The monitor instance that watches for new user events.
    def monitor
      @monitor ||= @booru.user_events.monitor(log: log, id: @id) do |user_event|
        handle_event(user_event)
      end
    end

    # Handles each new user event by checking for sockpuppets and posting a message to the sockpuppet channel if any are found.
    def handle_event(user_event)
      sockpuppets = sockpuppet_users(user_event)

      log.debug do
        [
          "[monitor/sockpuppets]",
          "user_event.id=#{user_event.id}",
          "user_event.category=#{user_event.category}",
          "user_event.user_id=#{user_event.user.id}",
          "user_event.user.name=#{user_event.user.name}",
          "sockpuppets=#{sockpuppets.map(&:id).to_json}",
        ].join(" ")
      end

      return if sockpuppets.empty? || cache.read("sockpuppet_monitor/#{user_event.user.id}/reported")

      cache.write("sockpuppet_monitor/#{user_event.user.id}/reported", true, expires_in: 24.hours)

      embed = build_embed(user_event, sockpuppets)
      sockpuppet_channel.send_message!(embeds: [embed])
    end

    # @return [Fumimi::DiscordEmbed] A Discord embed summarizing the sockpuppet event.
    def build_embed(user_event, sockpuppets)
      embed = Fumimi::DiscordEmbed.new
      embed.title = user_event.user.name
      embed.url = user_event.user.url
      embed.color = Fumimi::Colors::BLUE

      session_url = "#{@booru.url}/user_events?search[session_id]=#{user_event.session_id}"
      sock_text = "Sock of #{sockpuppets.first.name} #{"and at least #{sockpuppets.size - 1} other users" if sockpuppets.size > 1}".strip
      embed.description = "[#{sock_text}](#{session_url})"

      banned_users = sockpuppets.select(&:is_banned)
      if banned_users.present?
        ban_url = "#{@booru.url}/bans?search[user_id]=#{banned_users.pluck(:id).join(",")}"
        embed.description += "\n#{banned_users.size} of these users [were already banned](#{ban_url})"
      else
        embed.description += "\nNo previous ban detected."
      end

      embed
    end

    # @return [Array<Fumimi::Model::User>] List of users that share the same session as the given user event.
    def sockpuppet_users(user_event)
      authorized_categories = %w[
        login login_verification reauthenticate logout user_creation user_deletion user_undeletion password_reset
        password_change email_change totp_enable totp_update totp_disable totp_login totp_reauthenticate
        backup_code_generate backup_code_login backup_code_reauthenticate api_key_create api_key_update api_key_delete
      ]

      related_events = @booru.user_events.index(
        "search[session_id]": user_event.session_id,
        "search[user_id_not_eq]": user_event.user.id,
        "search[category]": authorized_categories.join(","),
        only: "id,category,user[id,name,is_banned]",
        limit: 1000,
      )

      related_events.pluck(:user).uniq(&:id)
    end
  end
end
