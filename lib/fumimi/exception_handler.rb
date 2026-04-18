require "fumimi/exceptions"

module Fumimi::ExceptionHandler
  def execute_and_rescue_errors(event, &block)
    response = block.call
  rescue StandardError, RestClient::Exception, NotImplementedError => e
    @log&.error e
    send_error(event, e)
  else
    response
  end

  def embed_for_exception(exception)
    error_embed = Discordrb::Webhooks::Embed.new

    if exception.is_a?(Fumimi::Exceptions::FumimiException) || exception.is_a?(Danbooru::Exceptions::DanbooruError)
      error_embed.title = exception&.embed_title
      error_embed.description = exception&.embed_description
      embed_image = exception&.embed_image
    end

    error_embed.title ||= "Exception Encountered!"
    error_embed.description ||= exception.to_s
    embed_image ||= "https://i.imgur.com/0CsFWP3.png"
    error_embed.image = Discordrb::Webhooks::EmbedImage.new(url: embed_image)
    error_embed
  end

  def send_error(event, exception)
    embed = embed_for_exception(exception)
    if event.respond_to?(:edit_response)
      event.edit_response(embeds: [embed])
    else
      event.channel.send_message("", false, [embed], nil, { replied_user: false }, event.message)
    end
  end
end
