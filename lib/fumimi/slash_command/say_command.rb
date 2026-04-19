require "fumimi/slash_command"

class Fumimi::SlashCommand::SayCommand < Fumimi::SlashCommand
  def self.name
    "say"
  end

  def self.description
    "Send a message to a channel by name (owners only)."
  end

  def self.options
    [
      { type: 7, name: "channel", description: "Target channel name.", required: true },
      { type: OPTION_TYPES[:string], name: "message", description: "Message to send. Supports pings.", required: true },
    ]
  end

  def self.ephemeral?
    true
  end

  def self.bits_to_view_command
    Discordrb::Permissions.new([:administrator]).bits
  end

  def respond_to_event
    channel = arguments[:channel].to_i
    message = arguments[:message]

    channel = @event.server.channels.detect { |c| c.id == channel }
    raise Fumimi::Exceptions::CommandArgumentError, "Unknown channel: #{channel_name}" if channel.blank?

    channel.send_message(message)
    @event.edit_response(content: "Sent.")
  end
end
