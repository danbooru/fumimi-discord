require "fumimi/class_register"
require "fumimi/exception_handler"

# Abstract base class for Discord slash commands.
#
# Slash commands are triggered by Discord slash command interactions (/commandname).
# Subclasses must implement {.name} and at least one of {#message}, {#embeds},
# or {#respond_to_event} to define the command's name and response.
#
# The command system automatically discovers and registers all subclasses via the
# {Fumimi::ClassRegister} mixin. Commands are registered using Discord's bulk
# command registration API to avoid rate limiting.
#
# Lifecycle:
# 1. User types a slash command in Discord (e.g., /calc 1+1)
# 2. Discord sends an interaction event to the bot
# 3. Bot looks up the command handler by name
# 4. Creates a new command instance and calls {#safe_handle_event}
# 5. Safe event handler calls {#respond_to_event} within exception wrapper
# 6. {#respond_to_event} calls {#message} and/or {#embeds} to generate response
# 7. Response is sent back to Discord as an interaction response
#
# Example:
#   class CalcCommand < Fumimi::SlashCommand
#     def self.name
#       "calc"
#     end
#
#     def self.description
#       "run a calculation"
#     end
#
#     def message
#       "Result: #{eval(arguments[:expression])}"
#     end
#   end
#
class Fumimi::SlashCommand
  include Fumimi::ClassRegister
  include Fumimi::ExceptionHandler

  OPTION_TYPES = { string: 3, integer: 4, boolean: 5, number: 10 }.freeze

  # The name of the command that users will type to invoke it.
  #
  # Must be unique across all commands and follow Discord's naming rules
  # (lowercase, alphanumeric and underscores only).
  #
  # @return [String] the command name
  # @raise [NotImplementedError] if not overridden by subclass
  #
  # @example
  #   def self.name
  #     "calc"
  #   end
  def self.name
    raise NotImplementedError, "Must implement a command name to respond to."
  end

  # The human-readable description of what the command does.
  #
  # Shown to users in Discord's command autocomplete. Optional but recommended.
  #
  # @return [String, nil] description of the command, or nil if not provided
  #
  # @example
  #   def self.description
  #     "run a calculation"
  #   end
  def self.description
  end

  # The list of options/parameters accepted by this command.
  #
  # Options are Discord slash command parameters that appear as fields in the
  # command interface. Each option is a hash with :name, :description, :type,
  # and optional :required, :min_value, :max_value, and other properties.
  #
  # Available types are defined in {OPTION_TYPES}.
  #
  # @return [Array<Hash>, nil] list of option hashes, or nil if no options
  #
  # @example
  #   def self.options
  #     [
  #       { type: OPTION_TYPES[:string], name: "expression", description: "math expression", required: true }
  #     ]
  #   end
  #
  # { type: OPTION_TYPES[:integer], name: "", description: ".", required: false, min_value: 1, max_value: 10 },
  def self.options
  end

  # Generates a plain text message for the response.
  #
  # This is called by {#respond_to_event} to generate the message content.
  # Either this, {#embeds}, or {#respond_to_event} must be overridden.
  #
  # @return [String, nil] the message text to send, or nil to skip message
  #
  # @example
  #   def message
  #     "Pong!"
  #   end
  def message
  end

  # Generates embeds for the response.
  #
  # This is called by {#respond_to_event} to generate embeds.
  # Either this, {#message}, or {#respond_to_event} must be overridden.
  #
  # @return [Array<Discordrb::Webhooks::Embed>, nil] array of embeds to send, or nil
  #
  # @example
  #   def embeds
  #     [create_embed_for_post]
  #   end
  def embeds
  end

  # Whether to show the "Bot is thinking..." indicator while processing.
  #
  # When true, Discord will show a typing indicator in the channel while waiting
  # for the response. Useful for commands that take time to process.
  #
  # @return [Boolean] true to show typing activity, false otherwise
  def show_typing_activity?
    true
  end

  # Returns the parsed command arguments as a hash.
  #
  # Arguments are indexed by option name and can be accessed as:
  #   arguments[:name]
  #   arguments["name"]
  #
  # @return [Hash] the parsed arguments with string keys converted to symbols
  #
  # @example
  #   # For command: /calc expression:1+1
  #   arguments[:expression]  # => "1+1"
  def arguments
    @event.options.with_indifferent_access
  end

  # Sends the command response.
  #
  # Calls {#message} and {#embeds} to generate response content, then edit the
  # interaction response with the message and/or embeds. At least one must be provided.
  #
  # @return [Object] result of event.edit_response call
  # @raise [NotImplementedError] if neither message nor embeds are provided
  # @raise [TypeError] if embeds is not an array
  def respond_to_event
    msg, embs = message, embeds
    raise NotImplementedError, "No message or embeds to return." if msg.blank? && embs.blank?
    raise TypeError, ".embeds must be an array" if embs.present? && !embs.is_a?(Array)

    @event.edit_response(content: msg, embeds: embs)
  end

  # Sends a reply message to the interaction.
  #
  # Edits the interaction response with the given message and other options.
  #
  # @param message [String] the message text to send
  # @param opts [Hash] additional options passed to edit_response (e.g., :embeds, :components)
  # @return [Object] result of event.edit_response call
  #
  # @example
  #   reply_to_user("Command failed!", embeds: [error_embed])
  def reply_to_user(message, **opts)
    @event.edit_response(content: message, **opts)
  end

  # Sends a message to a specific channel.
  #
  # Posts a message directly to a channel instead of replying to the interaction.
  # Useful for sending notifications or updates to other channels.
  #
  # @param message [String] the message text to send
  # @param channel [String, nil] channel ID or name to post in, defaults to current channel
  # @param opts [Hash] additional options passed to send_message
  # @return [Object] result of channel.send_message call
  #
  # @example
  #   send_to_channel("Moderation alert", channel: "mod-logs")
  def send_to_channel(message, channel: nil, **opts)
    if channel
      channel = @event.channels[channel]
    else
      channel = @event.channel
    end
    channel.send_message(message, **opts)
  end

  ## Internal methods

  # Initializes a command instance with interaction and configuration.
  #
  # Called when a slash command is invoked. Sets up the command with access to
  # caching, logging, and the Danbooru API client.
  #
  # @param event [Discordrb::Events::InteractionCreateEvent] the Discord interaction event
  # @param cache [Zache] optional cache instance (defaults to new Zache)
  # @param log [Logger] optional logger instance
  # @param booru [Danbooru] optional Danbooru API client
  # @param _args [Hash] additional arguments (ignored)
  def initialize(event, cache: nil, log: nil, booru: nil, **_args)
    @event = event
    @cache = cache || Zache.new
    @booru = booru
    @log = log
  end

  # Registers all slash command subclasses with Discord.
  #
  # First checks if existing commands are outdated to avoid unnecessary API calls
  # and rate limiting. If updates are needed, performs bulk registration.
  #
  # Called during bot startup to ensure all commands are available.
  #
  # @param opts [Hash] keyword arguments passed to {register} and {register_all}
  #   including :bot, :server_id, :log
  # @return [void]
  def self.register_all(**opts)
    register_slash_commands(**opts) if outdated_commands?(**opts)
    super
  end

  # Registers a single command handler with the bot.
  #
  # Called by {register_all} for each subclass. Sets up an application command handler
  # that creates a new command instance and calls {#safe_handle_event} when invoked.
  #
  # @param command [Class] the command subclass to register
  # @param bot [Discordrb::Bot] the Discord bot instance
  # @param opts [Hash] keyword arguments including cache, logger, booru client
  # @return [Proc] the command handler registered with the bot
  def self.register(command, bot:, **opts)
    opts[:cache] ||= Zache.new
    bot.application_command(command.name) do |event|
      kommand = command.new(event, **opts)
      kommand.safe_handle_event
    end
  end

  # Wraps command handling with exception handling and error logging.
  #
  # Logs the command invocation and calls {#respond_to_event} within an exception
  # handler that sanitizes errors and sends appropriate error messages to the user.
  #
  # @return [Object] result of {#respond_to_event}
  def safe_handle_event
    execute_and_rescue_errors(@event) do
      @log.info("command='/#{self.class.name}' args=`#{@event.options}` user_id=#{@event.user.id} username='#{@event.user.username}' channel='##{@event.channel.name}'") # rubocop:disable Layout/LineLength
      @event.channel.start_typing if show_typing_activity?
      respond_to_event
    end
  end

  # Checks if registered commands on Discord are outdated.
  #
  # Compares the subclasses' command definitions with what's currently registered
  # on the Discord server. Returns true if any commands are missing or have
  # different descriptions or options.
  #
  # @param bot [Discordrb::Bot] the Discord bot instance
  # @param server_id [String] the ID of the Discord server
  # @param log [Logger] logger instance for outputting debug messages
  # @param _args [Hash] other ignored arguments
  # @return [Boolean] true if commands need updating, false otherwise
  def self.outdated_commands?(bot:, server_id:, log:, **_args)
    response = Discordrb::API::Application.get_guild_commands(bot.token,
                                                              bot.profile.id,
                                                              server_id)

    existing_commands = JSON.parse(response.body, symbolize_names: true).index_by { |c| c[:name] }

    subclasses.map(&:to_h).any? do |new_command|
      existing = existing_commands[new_command[:name]]
      outdated = existing.nil?
            || existing[:description] != new_command[:description]
            || (existing[:options] || []) != new_command[:options]

      log.debug("Refreshing outdated slash command /#{new_command[:name]}.") if outdated
      outdated
    end
  end

  # Performs bulk registration of all commands with Discord.
  #
  # Registers all command subclasses in a single API call to avoid rate limiting.
  # Should only be called when {outdated_commands?} returns true.
  #
  # @param bot [Discordrb::Bot] the Discord bot instance
  # @param server_id [String] the ID of the Discord server
  # @param _args [Hash] other ignored arguments
  # @return [Object] result of bulk registration API call
  def self.register_slash_commands(bot:, server_id:, **_args)
    # register the commands in bulk to avoid ratelimiting, and to make sure they're all refreshed

    Discordrb::API::Application.bulk_overwrite_guild_commands(
      bot.token,
      bot.profile.id,
      server_id,
      subclasses.map(&:to_h)
    )
  end

  # Converts the command to a hash for Discord's API.
  #
  # Generates a hash representation suitable for Discord's create/update command APIs.
  # Removes :required from options when it's false as Discord only needs it when true.
  #
  # @return [Hash<Symbol, Object>] command hash with :name, :description, and :options keys
  def self.to_h # rubocop:disable Metrics/CyclomaticComplexity
    command_options = options&.map(&:with_indifferent_access)&.map(&:symbolize_keys) || []
    command_options.each { |opt| opt.delete(:required) if opt[:required] == false }
    { name: name, description: description, options: command_options }.symbolize_keys
  end
end
