class Fumimi
  # Manages registration and synchronization of slash commands with Discord.
  class SlashCommandRegistry
    attr_reader :fumimi

    delegate :bot, :server, :log, to: :fumimi

    # @param fumimi [Fumimi::Bot] The Fumimi bot instance.
    def initialize(fumimi:)
      @fumimi = fumimi
    end

    # Registers all commands with Discord, and sets up event handlers for incoming slash command interactions.
    def register_all
      refresh_commands!

      command_classes.each do |command|
        register(command)
      end
    end

    # Registers event handlers for one slash command subclass.
    #
    # @param command [Fumimi::SlashCommand] The slash command subclass to register.
    def register(command)
      class_name = command.to_s

      bot.application_command(command.name) do |event|
        kommand = class_name.constantize.new(fumimi, event)
        kommand.safe_handle_event
      end

      options = command.options.to_a.select { |opt| opt[:autocomplete] }
      options.map do |option|
        bot.autocomplete(option[:name], command_name: command.name) do |event|
          kommand = class_name.constantize.new(fumimi, event)
          kommand.handle_autocomplete
        end
      end
    end

    # Re-register all commands in Discord if any commands have changed or new commands have been added.
    def refresh_commands!
      return if outdated_definitions.none?

      log.info { "Updating slash commands: #{outdated_definitions.map { |defn| defn[:name] }.join(", ")}" }
      bulk_overwrite_guild_commands!(local_definitions.values)
    end

    # @return [Array<Hash>] List of command definitions that have changed and need to be updated in Discord.
    def outdated_definitions
      local_definitions.values - remote_definitions.values
    end

    # @return [Hash<String, Hash>] Map of command names to their local command definitions.
    def local_definitions
      @local_definitions ||= command_classes.index_by(&:name).transform_values(&:definition).with_indifferent_access
    end

    # @return [Hash<String, Hash>] Map of command names to their registered definitions in the Discord API.
    def remote_definitions
      @remote_definitions ||= commands.transform_values do |command|
        command.slice("name", "description", "options", "default_member_permissions").to_h.compact_blank.with_indifferent_access
      end
    end

    # @return [Hash<String, Hash>] Map of command names to command info in the Discord API.
    def commands
      # XXX Can't use this because it doesn't return default_member_permissions
      # @commands ||= bot.get_application_commands(server_id: server.id).index_by(&:name).with_indifferent_access

      @commands ||= Discordrb::API::Application.get_guild_commands(bot.token, bot.profile.id, server.id).then do |response|
        JSON.parse(response.body).index_by { |cmd| cmd["name"] }.with_indifferent_access
      end
    end

    # Register slash commands with Discord, overwriting all existing commands.
    #
    # @param definitions [Array<Hash>] List of command definitions to register.
    def bulk_overwrite_guild_commands!(definitions)
      Discordrb::API::Application.bulk_overwrite_guild_commands(bot.token, bot.profile.id, server.id, definitions)
    end

    # @return [Array<Class>] The list of all slash command subclasses.
    def command_classes
      Zeitwerk::Loader.eager_load_namespace(Fumimi::SlashCommand)
      Fumimi::SlashCommand.subclasses
    end
  end
end
