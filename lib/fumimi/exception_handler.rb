require "fumimi/exceptions"

module Fumimi::ExceptionHandler
  def execute_and_rescue_errors(event, slash_command: false, wait_message: true, &block)
    thinking_message = create_thinking_message(event, slash_command: slash_command) if wait_message
    event.channel.start_typing
    response = block.call
  rescue Fumimi::Exceptions::PermissionError
    event.drain
    send_error(event.channel, "No Permissions", "You can't do that! Stop touching me that way!", img: "https://imgur.com/fZ4Hr2g.jpg")
  rescue Fumimi::Exceptions::CommandArgumentError => e
    event << "```#{e}```"
  rescue Danbooru::Response::TimeoutError
    send_error(event.channel, "Timeout Encontered!", "The query went into timeout...")
  rescue Danbooru::Response::MaintenanceError
    send_error(event.channel, "Downbooru!", "The site is down for maintenance!", img: "https://i.imgur.com/DHMBEGZ.png")
  rescue Danbooru::Response::DownbooruError
    send_error(event.channel, "Downbooru!", "The site is down!", img: "https://i.imgur.com/DHMBEGZ.png")
  rescue StandardError, RestClient::Exception => e
    event.drain unless slash_command
    @log.error e
    send_error(event.channel, "Exception Encountered!", e.to_s)
  else
    response
  ensure
    thinking_message&.delete unless slash_command
  end

  def send_error(channel, title, description, img: nil)
    channel.send_embed do |embed|
      embed.title = title
      embed.description = description
      embed.image = Discordrb::Webhooks::EmbedImage.new(url: img || "https://i.imgur.com/0CsFWP3.png")
      embed
    end
  end

  def create_thinking_message(event, slash_command: false)
    if slash_command
      event.defer(ephemeral: false)
    else
      event.send_message "*Please wait warmly until Fumimi is ready. This may take up to 10 seconds.*"
    end
  end
end
