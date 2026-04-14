require "discordrb"

# Wrapper to handle discord fields getting too long
class Fumimi::DiscordEmbed < Discordrb::Webhooks::Embed
  MAX_MESSAGE_LENGTH = 5800

  def add_field(name: nil, value: nil, inline: nil)
    if length + (value.to_s.length || 0) + (name.to_s.length || 0) > MAX_MESSAGE_LENGTH
      raise Fumimi::Exceptions::FumimiException
    end

    super
  end

  def length # rubocop:disable Metrics/PerceivedComplexity,Metrics/CyclomaticComplexity
    length = title.length
    length += author&.name&.length || 0
    length += footer&.text || 0
    length += description&.length || 0
    length += fields&.sum { |e| e.name.length + e.value.length } || 0
    length
  end
end
