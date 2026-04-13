require "fumimi/exception_handler"

# Abstract class for a fumimi command.
#
# Required implementations:
# * self.name
# * one of message, embed, or respond_to_event
#
# Optional implementations:
# * self.description
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

  def respond_to_event
    if message
      send_to_channel(message)
    elsif embed
      raise NotImplementedError
      # @event.channel.send_embed(embed)
    else
      raise NotImplementedError, "Must implement either .message, .embed., or .respond_to_event"
    end
  end

  # Utility alias for event.options
  def arguments
    @event.options
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

  @@commands = [] # rubocop:disable Style/ClassVars

  def self.inherited(klass)
    @@commands << klass
    super
  end

  def initialize(event, cache: nil, log: nil)
    @event = event
    @cache = cache || Zache.new
    @log = log
  end

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
        klass = command.new(event, **opts)
        klass.execute_and_rescue_errors(event, slash_command: true) do
          klass.respond_to_event
        end
      end
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
