require "fumimi/exceptions"

module Fumimi::ExceptionHandler
  def execute_and_rescue_errors(event, wait_message: true, &block)
    thinking_message = create_thinking_message(event) if wait_message
    response = block.call
  rescue Fumimi::Exceptions::PermissionError
    event.drain
    send_error(event, "No Permissions", "You can't do that! Stop touching me that way!", img: "https://imgur.com/fZ4Hr2g.jpg")
  rescue Fumimi::Exceptions::CommandArgumentError => e
    if slash_command?(event)
      send_error(event, "Bad Argument!", e)
    else
      event << "```#{e}```"
    end
  rescue Danbooru::Response::TimeoutError
    send_error(event, "Timeout Encontered!", "The query went into timeout...")
  rescue Danbooru::Response::MaintenanceError
    send_error(event, "Downbooru!", "The site is down for maintenance!", img: "https://i.imgur.com/DHMBEGZ.png")
  rescue Danbooru::Response::DownbooruError
    send_error(event, "Downbooru!", "The site is down!", img: "https://i.imgur.com/DHMBEGZ.png")
  rescue StandardError, RestClient::Exception => e
    event.drain unless slash_command?(event)
    @log&.error e
    send_error(event, "Exception Encountered!", e.to_s)
  else
    response
  ensure
    thinking_message&.delete unless slash_command?(event)
  end

  def send_error(event, title, description, img: nil)
    error_embed = Discordrb::Webhooks::Embed.new
    error_embed.title = title
    error_embed.description = description
    error_embed.image = Discordrb::Webhooks::EmbedImage.new(url: img || "https://i.imgur.com/0CsFWP3.png")

    if slash_command?(event)
      event.edit_response(embeds: [error_embed])
    else
      event.channel.send_embed(error_embed)
    end
  end

  def create_thinking_message(event)
    if slash_command?(event)
      event.defer(ephemeral: false)
    else
      event.send_message "*Please wait warmly until Fumimi is ready. This may take up to 10 seconds.*"
    end
  end

  def slash_command?(event)
    event.is_a?(Discordrb::Events::ApplicationCommandEvent)
  end
end
