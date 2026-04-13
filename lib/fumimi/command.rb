require "fumimi/exception_handler"

# Abstract class for a fumimi command.
#
# Required implementations:
# * self.name
# * one of message, embed, or respond_to_event
#
# Optional implementations:
# * self.options
# * self.description
# * self.show_typing_activity?
class Fumimi::Command
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

  def message
  end

  def embed
  end

  # Whether to send the "fumimi is typing..." message to the chat.
  def show_typing_activity?
    true
  end

  def respond_to_event
    if message
      reply_to_user(message)
    elsif embed
      raise NotImplementedError
      # @event.channel.send_embed(embed)
    else
      raise NotImplementedError, "Must implement either .message, .embed., or .respond_to_event"
    end
  end

  # Utility alias for event.options
  def arguments
    @event.options.with_indifferent_access
  end

  # Reply to the user
  def reply_to_user(message)
    @event.edit_response(content: message)
  end

  # Post directly in the channel
  def send_to_channel(message, channel: nil)
    if channel
      channel = @event.channels[channel]
    else
      channel = @event.channel
    end
    channel.send_message(message)
  end

  def initialize(event, cache: nil, log: nil)
    @event = event
    @cache = cache || Zache.new
    @log = log
  end

  @@commands = [] # rubocop:disable Style/ClassVars

  def self.inherited(kommand)
    @@commands << kommand
    super
  end

  # Registers all classes that inherit this class as commands
  def self.register_all(bot, server_id, log: nil)
    opts = {
      cache: Zache.new,
      log: log,
    }

    # unregister_stale_commands(bot, server_id)

    @@commands.each do |command|
      log.debug("Registering slash command /#{command.name}.")
      # register the command
      bot.register_application_command(command.name, command.description, server_id: server_id) do |cmd|
        command.options(cmd)
      end

      # register how the command replies
      bot.application_command(command.name) do |event|
        kommand = command.new(event, **opts)
        kommand.safe_handle_event
      end
    end
  end

  # makes sure that fumimi exceptions are invoked to sanitize errors
  def safe_handle_event
    execute_and_rescue_errors(@event) do
      @event.channel.start_typing if show_typing_activity?
      respond_to_event
    end
  end

  # Unregister old stale commands.
  # Uncommented for now because I don't know how it behaves with the commands sent by Danbooru (/count etc)
  def self.unregister_stale_commands(bot, server_id)
    bot.get_application_commands(server_id: server_id).each do |command|
      unless @@commands.map(&:name).include? command.name
        log.debug("Removing stale command /#{command.name}.")
        command.delete
      end
    end
  end
end
