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

  # Default bits that decide whether a user can see this command.
  # https://docs.discord.com/developers/topics/permissions
  # Can be overriden in server settings > integration > fumimi > /<command name>
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
    raise NotImplementedError, "No message or embeds to return." if msg.blank? && embs.nil?
    raise TypeError, ".embeds must be an array" if embs.present? && !embs.is_a?(Array)
    raise Fumimi::Exceptions::NoResultsError if embs == [] && msg.blank?

    @event.edit_response(content: msg, embeds: embs)
  end

  ## Internal methods

  # @param event [Discordrb::Events::InteractionCreateEvent]
  # @param fumimi [Fumimi]
  def initialize(event, fumimi:)
    @event = event
    @fumimi = fumimi
    @booru = fumimi.booru
    @log = fumimi.log
    @cache = fumimi.cache
    @report_channel_name = fumimi.report_channel_name
  end

  # Registers all commands, refreshing Discord definitions only when needed.
  #
  # @param fumimi [Fumimi]
  # @return [void]
  def self.register_all(fumimi:)
    register_slash_commands(fumimi:) if outdated_commands?(fumimi:)
    super
  end

  # Registers one slash command subclass with the bot.
  #
  # @param command [Class]
  # @param fumimi [Fumimi]
  # @return [Proc]
  def self.register(command, fumimi:)
    fumimi.bot.application_command(command.name) do |event|
      kommand = command.new(event, fumimi:)
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
  # @param fumimi [Fumimi]
  # @return [Boolean]
  def self.outdated_commands?(fumimi:)
    response = Discordrb::API::Application.get_guild_commands(fumimi.bot.token, fumimi.bot.profile.id, fumimi.server_id)

    existing_commands = JSON.parse(response.body, symbolize_names: true).index_by { |c| c[:name] }
    subclasses.map do |subclass|
      old_command = existing_commands[subclass.name] || {}
      new_command = subclass.to_h

      next false if new_command.keys.none? { |key| old_command[key].presence != new_command[key].presence }

      fumimi.log.debug("Refreshing outdated slash command /#{new_command[:name]}.")
      true
    end.any?
  end

  # Bulk-updates all slash command definitions in one API call.
  #
  # @param fumimi [Fumimi]
  # @return [Object]
  def self.register_slash_commands(fumimi:)
    Discordrb::API::Application.bulk_overwrite_guild_commands(
      fumimi.bot.token,
      fumimi.bot.profile.id,
      fumimi.server_id,
      subclasses.map(&:to_h),
    )
  end

  # Builds the Discord API payload for this command.
  #
  # @return [Hash<Symbol, Object>]
  def self.to_h
    command_options = options&.map(&:with_indifferent_access)&.map(&:symbolize_keys) || []
    command_options.each { |opt| opt.delete(:required) if opt[:required] == false }

    command_hash = { name: name, description: description, options: command_options }.symbolize_keys
    command_hash[:default_member_permissions] = bits_to_view_command.to_s if bits_to_view_command

    command_hash
  end
end
