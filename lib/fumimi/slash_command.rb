# Base class for Discord slash commands.
#
# Subclasses are auto-registered and should define {.name} plus a response via
# {#message}, {#embeds}, or a custom {#respond_to_event}.
#
class Fumimi::SlashCommand < Fumimi::Event
  OPTION_TYPES = { string: 3, integer: 4, boolean: 5, number: 10 }.freeze

  # @return [String] Command name users type in Discord.
  def self.name
    raise NotImplementedError, "Must implement a command name to respond to."
  end

  # @return [String, nil] Short command description shown in Discord.
  def self.description
  end

  # @return [Array<Hash>, nil] # Slash command option definitions.
  def self.options
    # { type: OPTION_TYPES[:integer], name: "", description: ".", required: false, min_value: 1, max_value: 10 },
  end

  # @return [Boolean] Whether the message is only visible to the user.
  def self.ephemeral?
    false
  end

  # Default bits that decide whether a user can see this command.
  # https://docs.discord.com/developers/topics/permissions
  # Can be overriden in server settings > integration > fumimi > /<command name>
  def self.default_member_permissions
    # Ex: Discordrb::Permissions.new([:administrator]).bits
  end

  # @return [Hash<Symbol, Object>] The Discord API payload used to define this command.
  def self.definition
    {
      name: name,
      description: description,
      options: options.to_a.map(&:compact_blank),
      default_member_permissions: default_member_permissions&.to_s,
    }.compact_blank.deep_symbolize_keys
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
end
