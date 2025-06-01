require "fumimi/exceptions"

module Fumimi::ExceptionHandler
  def execute_and_rescue_errors(event, &block)
    message = event.send_message "*Please wait warmly until Fumimi is ready. This may take up to 10 seconds.*"
    event.channel.start_typing
    response = block.call
  rescue Fumimi::Exceptions::PermissionError
    event.drain
  rescue Fumimi::Exceptions::CommandArgumentError => e
    event << "```#{e}```"
  rescue Danbooru::Response::TimeoutError
    send_error(event.channel, "Timeout Encontered!", "The query went into timeout...")
  rescue Danbooru::Response::DownbooruError
    send_error(event.channel, "Downbooru!", "The site is down for maintenance!", img: "https://i.imgur.com/DHMBEGZ.png")
  rescue StandardError, RestClient::Exception => e
    event.drain
    @log.error e
    send_error(event.channel, "Exception Encountered!", e.to_s)
  else
    response
  ensure
    message.delete
  end

  def send_error(channel, title, description, img: nil)
    channel.send_embed do |embed|
      embed.title = title
      embed.description = description
      embed.image = Discordrb::Webhooks::EmbedImage.new(url: img || "https://i.imgur.com/0CsFWP3.png")
      embed
    end
  end
end
