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

  # The name of the command.
  #   Example: "calc"
  def self.name
    raise NotImplementedError, "Must implement a command name to respond to."
  end

  # The description of the command (optional).
  #   Example: "run a calculation"
  def self.description
  end

  # The options of a command, in discord.rb style
  # https://github.com/shardlab/discordrb/blob/main/examples/slash_commands.rb#L36-L38
  #   Ex.
  #     cmd.string("option name", "help message", required: true)
  #     cmd.boolean("option name", "help message")
  def self.options(cmd)
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

  # by default the bot responds to the user.
  # commands that do more than one message at once should override this
  # note that multiple embeds can be sent at once by overriding .embeds instead
  def respond_to_event
    @event.edit_response(content: message, embeds: embeds)
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

  def initialize(event, cache: nil, log: nil, booru: nil)
    @event = event
    @cache = cache || Zache.new
    @booru = booru
    @log = log
  end

  def self.register(command, **opts)
    bot = opts[:bot]
    log = opts[:log]
    server_id = opts[:server_id]
    opts[:cache] ||= Zache.new
    init_opts = opts.slice(:cache, :log, :booru)

    # register the command
    log.debug("Registering slash command /#{command.name}.")
    bot.register_application_command(command.name, command.description, server_id: server_id) do |cmd|
      command.options(cmd)
    end

    # register how the command replies
    bot.application_command(command.name) do |event|
      kommand = command.new(event, **init_opts)
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
end
