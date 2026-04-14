require "fumimi/discord_embed"

module Fumimi::HasDiscordEmbed
  def embed # rubocop:disable Metrics/CyclomaticComplexity,Metrics/PerceivedComplexity
    @embed ||= Fumimi::DiscordEmbed.new
    @embed.title = embed_title

    @embed.description = embed_description if embed_description.present?

    @embed.url = embed_url if embed_url.present?
    @embed.author = Discordrb::Webhooks::EmbedAuthor.new(**embed_author) if embed_author.present?
    @embed.color = embed_color if embed_color.present?

    @embed.timestamp = embed_timestamp if embed_timestamp.present?
    @embed.footer = Discordrb::Webhooks::EmbedFooter.new(text: embed_footer) if embed_footer.present?

    @embed.fields = []
    embed_fields.to_a.each do |field|
      @embed.add_field(**field)
    end

    @embed
  end

  def embed_title
    raise NotImplementedError
  end

  def embed_url
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
