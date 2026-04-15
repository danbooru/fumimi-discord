require "fumimi/discord_embed"

module Fumimi::HasDiscordEmbed
  attr_accessor :channel

  def embed(channel:)
    @channel ||= channel
    @embed ||= Fumimi::DiscordEmbed.new
    populate_embed
  end

  private

  def populate_embed
    @embed.title       = embed_title
    @embed.description = embed_description.to_s
    @embed.url         = embed_url
    @embed.color       = embed_color
    @embed.timestamp   = embed_timestamp
    @embed.image       = embed_image
    @embed.thumbnail   = embed_thumbnail unless embed_image.present?

    @embed.author      = embed_author
    @embed.footer      = embed_footer

    @embed.fields.clear
    embed_fields.to_a.each { |field| @embed.add_field(**field) }

    @embed
  end

  def embed_title
    raise NotImplementedError
  end

  def embed_url
  end

  # This takes priority over embed_thumbnail
  def embed_image
  end

  def embed_thumbnail
  end

  # { name: String, url: String }
  # or
  # string
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
