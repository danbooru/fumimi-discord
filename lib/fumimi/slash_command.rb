require "fumimi/class_register"
require "fumimi/exception_handler"

# Abstract class for a fumimi slash command.
#
# Required implementations:
# * self.name
# * one of message, embeds, or respond_to_event
#
# Optional implementations:
# * self.options
# * self.description
# * self.show_typing_activity?
class Fumimi::SlashCommand
  include Fumimi::ClassRegister
  include Fumimi::ExceptionHandler

  OPTION_TYPES = { string: 3, integer: 4, boolean: 5, number: 10 }.freeze

  # The name of the command.
  #   Example: "calc"
  def self.name
    raise NotImplementedError, "Must implement a command name to respond to."
  end

  # The description of the command (optional).
  #   Example: "run a calculation"
  def self.description
  end

  # { type: OPTION_TYPES[:integer], name: "", description: ".", required: false, min_value: 1, max_value: 10 },
  def self.options
  end

  # Override this to reply with a single message
  def message
  end

  # Override this to attach embeds to your reply
  def embeds
  end

  # Whether to send the "fumimi is typing..." message to the chat.
  def show_typing_activity?
    true
  end

  def arguments
    @event.options.with_indifferent_access
  end

  def channel
    @event.channel
  end

  def user
    @event.user
  end

  def respond_to_event
    msg, embs = message, embeds
    raise NotImplementedError, "No message or embeds to return." if msg.blank? && embs.blank?
    raise TypeError, ".embeds must be an array" if embs.present? && !embs.is_a?(Array)

    @event.edit_response(content: msg, embeds: embs)
  end

  # Reply to the user
  def reply_to_user(message, **opts)
    @event.edit_response(content: message, **opts)
  end

  # Post directly in the channel
  def send_to_channel(message, channel: nil, **opts)
    if channel
      channel = @event.channels[channel]
    else
      channel = @event.channel
    end
    channel.send_message(message, **opts)
  end

  ## Internal methods

  def initialize(event, cache: nil, log: nil, booru: nil, **_args)
    @event = event
    @cache = cache || Zache.new
    @booru = booru
    @log = log
  end

  def self.register_all(**opts)
    register_slash_commands(**opts) if outdated_commands?(**opts)
    super
  end

  # register how the command replies to a message
  def self.register(command, bot:, **opts)
    opts[:cache] ||= Zache.new
    bot.application_command(command.name) do |event|
      kommand = command.new(event, **opts)
      kommand.safe_handle_event
    end
  end

  # makes sure that fumimi exceptions are invoked to sanitize errors
  def safe_handle_event
    execute_and_rescue_errors(@event) do
      @log.info("command='/#{self.class.name}' args=`#{@event.options}` user_id=#{user.id} username='#{user.username}' channel='##{channel.name}'") # rubocop:disable Layout/LineLength
      channel.start_typing if show_typing_activity?
      respond_to_event
    end
  end

  # Discord ratelimits slash command endpoints
  # So we just check if the existing commands are misaligned before we try resyncing them.
  # This is not an issue in prod, but in dev when testing stuff you can quickly get ratelimited limit.
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

  def self.register_slash_commands(bot:, server_id:, **_args)
    # register the commands in bulk to avoid ratelimiting, and to make sure they're all refreshed

    Discordrb::API::Application.bulk_overwrite_guild_commands(
      bot.token,
      bot.profile.id,
      server_id,
      subclasses.map(&:to_h)
    )
  end

  def self.to_h # rubocop:disable Metrics/CyclomaticComplexity
    command_options = options&.map(&:with_indifferent_access)&.map(&:symbolize_keys) || []
    command_options.each { |opt| opt.delete(:required) if opt[:required] == false }
    { name: name, description: description, options: command_options }.symbolize_keys
  end
end
