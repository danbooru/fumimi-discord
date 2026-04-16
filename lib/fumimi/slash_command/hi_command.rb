require "fumimi/slash_command"

class Fumimi::SlashCommand::HiCommand < Fumimi::SlashCommand
  def self.name
    "hi"
  end

  def self.description
    "Say hi to Fumimi!"
  end

  def respond_to_event
    reply_to_user "Command received. Deleting all animes."
    sleep 1

    send_to_channel "5..."
    sleep 1
    send_to_channel "4..."
    sleep 1
    send_to_channel "3..."
    sleep 1
    send_to_channel "2..."
    sleep 1
    send_to_channel "1..."
    sleep 1

    send_to_channel "Done! Animes deleted."
  end
end
