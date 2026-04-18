require "fumimi/class_register"
require "fumimi/exception_handler"

# Base class for Discord slash commands.
#
# Subclasses are auto-registered and should define {.name} plus a response via
# {#message}, {#embeds}, or a custom {#respond_to_event}.
#
class Fumimi::SlashCommand
  include Fumimi::ClassRegister
  include Fumimi::ExceptionHandler

  OWNERS = [310167383912349697, 1373735183425208331].freeze # rubocop:disable Style/NumericLiterals

  OPTION_TYPES = { string: 3, integer: 4, boolean: 5, number: 10 }.freeze

  # Command name users type in Discord.
  #
  # @return [String]
  # @raise [NotImplementedError]
  def self.name
    raise NotImplementedError, "Must implement a command name to respond to."
  end

  # Short command description shown in Discord.
  #
  # @return [String, nil]
  def self.description
  end

  # Slash command option definitions.
  #
  # @return [Array<Hash>, nil]
  #
  # { type: OPTION_TYPES[:integer], name: "", description: ".", required: false, min_value: 1, max_value: 10 },
  def self.options
  end

  # Plain text response body.
  #
  # @return [String, nil]
  def message
  end

  # Embed response body.
  #
  # @return [Array<Discordrb::Webhooks::Embed>, nil]
  def embeds
  end

  # Parsed slash command arguments.
  #
  # @return [Hash]
  def arguments
    @event.options.with_indifferent_access
  end

  # Whether the message is only visible to the user.
  #
  # @return [Boolean]
  def self.ephemeral?
    false
  end

  # Bits that decide whether a user can see this command.
  # https://docs.discord.com/developers/topics/permissions
  def self.bits_to_view_command
    # Ex: Discordrb::Permissions.new([:administrator]).bits
  end

  # Sends the interaction response using {#message} and {#embeds}.
  #
  # @return [Object]
  # @raise [NotImplementedError]
  # @raise [TypeError]
  def respond_to_event
    msg, embs = message, embeds
    raise NotImplementedError, "No message or embeds to return." if msg.blank? && embs.blank?
    raise TypeError, ".embeds must be an array" if embs.present? && !embs.is_a?(Array)

    @event.edit_response(content: msg, embeds: embs)
  end

  ## Internal methods

  # @param event [Discordrb::Events::InteractionCreateEvent]
  # @param cache [Zache, nil]
  # @param log [Logger, nil]
  # @param booru [Danbooru, nil]
  # @param _args [Hash]
  def initialize(event, cache: nil, log: nil, booru: nil, **_args)
    @event = event
    @cache = cache
    @booru = booru
    @log = log
  end

  # Registers all commands, refreshing Discord definitions only when needed.
  #
  # @param opts [Hash]
  # @return [void]
  def self.register_all(**opts)
    register_slash_commands(**opts) if outdated_commands?(**opts)
    super
  end

  # Registers one slash command subclass with the bot.
  #
  # @param command [Class]
  # @param bot [Discordrb::Bot]
  # @param opts [Hash]
  # @return [Proc]
  def self.register(command, bot:, **opts)
    bot.application_command(command.name) do |event|
      kommand = command.new(event, **opts)
      kommand.safe_handle_event
    end
  end

  # Handles command execution with logging and exception wrapping.
  #
  # @return [Object]
  def safe_handle_event
    execute_and_rescue_errors(@event) do
      @log.info("command='/#{self.class.name}' args=`#{@event.options}` user_id=#{@event.user.id} username='#{@event.user.username}' channel='##{@event.channel.name}'") # rubocop:disable Layout/LineLength

      @event.defer(ephemeral: self.class.ephemeral?)
      respond_to_event
    end
  end

  # Returns true when local command definitions differ from Discord's.
  #
  # @param bot [Discordrb::Bot]
  # @param server_id [String]
  # @param log [Logger]
  # @param _args [Hash]
  # @return [Boolean]
  def self.outdated_commands?(bot:, server_id:, log:, **_args)
    response = Discordrb::API::Application.get_guild_commands(bot.token,
                                                              bot.profile.id,
                                                              server_id)

    existing_commands = JSON.parse(response.body, symbolize_names: true).index_by { |c| c[:name] }
    subclasses.map do |subclass|
      old_command = existing_commands[subclass.name] || {}
      new_command = subclass.to_h

      next false if new_command.keys.none? { |key| old_command[key].presence != new_command[key].presence }

      log.debug("Refreshing outdated slash command /#{new_command[:name]}.")
      true
    end.any?
  end

  # Bulk-updates all slash command definitions in one API call.
  #
  # @param bot [Discordrb::Bot]
  # @param server_id [String]
  # @param _args [Hash]
  # @return [Object]
  def self.register_slash_commands(bot:, server_id:, **_args)
    # register the commands in bulk to avoid ratelimiting, and to make sure they're all refreshed

    Discordrb::API::Application.bulk_overwrite_guild_commands(
      bot.token,
      bot.profile.id,
      server_id,
      subclasses.map(&:to_h)
    )
  end

  # Builds the Discord API payload for this command.
  #
  # @return [Hash<Symbol, Object>]
  def self.to_h # rubocop:disable Metrics/CyclomaticComplexity,Metrics/PerceivedComplexity
    command_options = options&.map(&:with_indifferent_access)&.map(&:symbolize_keys) || []
    command_options.each { |opt| opt.delete(:required) if opt[:required] == false }

    command_hash = { name: name, description: description, options: command_options }.symbolize_keys
    command_hash[:default_member_permissions] = bits_to_view_command.to_s if bits_to_view_command

    command_hash
  end
end
