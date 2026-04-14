require "fumimi/discord_embed"

module Fumimi::HasDiscordEmbed
  def embed(nsfw_channel: false) # rubocop:disable Metrics/CyclomaticComplexity,Metrics/PerceivedComplexity
    embed = Fumimi::DiscordEmbed.new
    embed.title = embed_title

    embed.description = embed_description if embed_description.present?

    embed.url = embed_url if embed_url.present?
    embed.author = Discordrb::Webhooks::EmbedAuthor.new(**embed_author) if embed_author.present?
    embed.color = embed_color if embed_color.present?

    embed.timestamp = embed_timestamp if embed_timestamp.present?
    embed.footer = Discordrb::Webhooks::EmbedFooter.new(text: embed_footer) if embed_footer.present?

    embed.fields = []
    embed_fields.to_a.each do |field|
      embed.add_field(**field)
    end

    if embed_image.present? && (nsfw_channel || !embed_is_nsfw?)
      embed.image = Discordrb::Webhooks::EmbedImage.new(url: embed_image)
    elsif embed_thumbnail.present? && (nsfw_channel || !embed_is_nsfw?)
      embed.thumbnail = Discordrb::Webhooks::EmbedThumbnail.new(url: embed_thumbnail)
    end

    embed
  end

  private

  def embed_title
    raise NotImplementedError
  end

  # whether the image of this embed should be restricted to nsfw channels
  def embed_is_nsfw?
    false
  end

  def embed_url
  end

  # This takes priority over embed_thumbnail
  def embed_image
  end

  def embed_thumbnail
  end

  # { name: String, url: String }
  def embed_author
  end

  def embed_description
  end

  def embed_color
  end

  # the timestamp is automatically normalized by discord to match each user's time
  def embed_timestamp
  end

  # displayed after the timestamp
  def embed_footer
  end

  # {inline: Boolean, name: String, value: String}
  def embed_fields
  end
end
