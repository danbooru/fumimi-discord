require "fumimi/exceptions"

module Fumimi::ExceptionHandler
  def execute_and_rescue_errors(event, wait_message: true, &block)
    thinking_message = create_thinking_message(event) if wait_message
    response = block.call
  rescue StandardError, RestClient::Exception => e
    @log&.error e
    send_error(event, e)
  else
    response
  ensure
    thinking_message&.delete unless slash_command?(event)
  end

  def send_error(event, exception)
    error_embed = Discordrb::Webhooks::Embed.new

    if [Fumimi::Exceptions::FumimiException, Danbooru::Exceptions::DanbooruError].member? exception.class
      error_embed.title = exception&.embed_title
      error_embed.description = exception&.embed_description
      embed_image = exception&.embed_image
    end

    error_embed.title ||= "Exception Encountered!"
    error_embed.description ||= exception.to_s
    embed_image ||= "https://i.imgur.com/0CsFWP3.png"
    error_embed.image = Discordrb::Webhooks::EmbedImage.new(url: embed_image)

    if slash_command?(event)
      event.edit_response(embeds: [error_embed])
    else
      event.drain
      event.channel.send_embed("", error_embed)
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
