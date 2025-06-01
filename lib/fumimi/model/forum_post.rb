require "fumimi/model"

class Fumimi::Model::ForumPost < Fumimi::Model
  include Fumimi::HasDTextFields

  HIDE_LOCKED_FORUMS = ENV.fetch("FUMIMI_HIDE_LOCKED_FORUMS", "true") =~ /\A(true|t|yes|y|on|1)\z/i

  def embed(embed, channel) # rubocop:disable Lint/UnusedMethodArgument
    raise Fumimi::Exceptions::PermissionError if hidden?

    embed.title = topic.title
    embed.url = url

    embed.author = Discordrb::Webhooks::EmbedAuthor.new(
      name: creator.at_name,
      url: creator.url
    )

    embed.description = pretty_body

    if try(:bulk_update_request).present?
      embed.description += "\n\n**BUR ##{bulk_update_request.id} (#{bulk_update_request.status.titleize}):**"
      embed.description += "\n#{bulk_update_request.pretty_bur}"
    end

    embed.footer = embed_footer

    embed
  end

  def hidden?
    topic.min_level > 0 && HIDE_LOCKED_FORUMS
  end
end
