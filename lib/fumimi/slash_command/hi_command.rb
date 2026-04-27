class Fumimi::SlashCommand::HiCommand < Fumimi::SlashCommand
  def self.name
    "hi"
  end

  def self.description
    "Say hi to Fumimi!"
  end

  def respond_to_event
    @event.edit_response(content: "Command received. Deleting all animes.")
    sleep 1

    @event.channel.send_message "5..."
    sleep 1
    @event.channel.send_message "4..."
    sleep 1
    @event.channel.send_message "3..."
    sleep 1
    @event.channel.send_message "2..."
    sleep 1
    @event.channel.send_message "1..."
    sleep 1

    @event.channel.send_message "Done! Animes deleted."
  end
end
