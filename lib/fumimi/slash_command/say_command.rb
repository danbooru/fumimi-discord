class Fumimi::SlashCommand::SayCommand < Fumimi::SlashCommand
  def self.name
    "say"
  end

  def self.description
    "Make Fumimi say something in the current channel."
  end

  def self.options
    [
      { type: OPTION_TYPES[:string], name: "message", description: "Message to send. Supports pings.", required: true },
    ]
  end

  def self.ephemeral?
    true
  end

  def respond_to_event
    event.channel.send_message!(content: arguments[:message])
    event.delete_response
  end
end
