class Fumimi
  class Event
    attr_reader :fumimi, :event

    delegate :booru, :log, :cache, to: :fumimi

    # @param fumimi [Fumimi::Bot] The Fumimi bot instance.
    # @param event [Discordrb::Events::Event] The Discordrb event object.
    def initialize(fumimi, event)
      @fumimi = fumimi
      @event = event
      @log = fumimi.log
      @cache = fumimi.cache
      @booru = fumimi.booru
    end

    # @param event [Discordrb::Events::Event] The Discord event to handle.
    def execute_and_rescue_errors(event, &block)
      block.call
    rescue StandardError, RestClient::Exception, NotImplementedError => e
      @log&.error e
      send_error(event, e)
    end

    # @param exception [Exception] The exception to create an embed for.
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

    # @param event [Discordrb::Events::Event] The event to send the error message in response to.
    # @param exception [Exception] The exception to send.
    def send_error(event, exception)
      embed = embed_for_exception(exception)
      if event.respond_to?(:edit_response)
        event.edit_response(embeds: [embed])
      else
        event.message.reply!("", embed: embed)
      end
    end
  end
end
