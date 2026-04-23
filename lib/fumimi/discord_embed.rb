require "discordrb"

class Fumimi::DiscordEmbed < Discordrb::Webhooks::Embed
  MAX_MESSAGE_LENGTH = 5800

  def add_field(name: nil, value: nil, inline: nil)
    if length + (value.to_s.length || 0) + (name.to_s.length || 0) > MAX_MESSAGE_LENGTH
      raise Fumimi::Exceptions::FumimiException
    end

    super
  end

  def length
    length = title.length
    length += author&.name&.length || 0
    length += footer&.text&.length || 0
    length += description&.length || 0
    length += fields&.sum { |e| e.name.length + e.value.length } || 0
    length
  end

  def author=(value)
    return unless value.present?

    if value.is_a?(Discordrb::Webhooks::EmbedAuthor)
      @author = value
    else
      value = { name: value.to_s } unless value.is_a?(Hash)
      @author = Discordrb::Webhooks::EmbedAuthor.new(**value)
    end
  end

  def image=(value)
    return unless value.present?

    if value.is_a?(Discordrb::Webhooks::EmbedImage)
      @image = value
    else
      @image = Discordrb::Webhooks::EmbedImage.new(url: value)
    end
  end

  def thumbnail=(value)
    return unless value.present?

    if value.is_a?(Discordrb::Webhooks::EmbedThumbnail)
      @thumbnail = value
    else
      @thumbnail = Discordrb::Webhooks::EmbedThumbnail.new(url: value)
    end
  end

  def footer=(value)
    return unless value.present?

    if value.is_a?(Discordrb::Webhooks::EmbedFooter)
      @footer = value
    else
      value = { text: value.to_s } unless value.is_a?(Hash)
      @footer = Discordrb::Webhooks::EmbedFooter.new(**value)
    end
  end
end
