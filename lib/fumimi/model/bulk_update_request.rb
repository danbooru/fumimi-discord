require "fumimi/model"

class Fumimi::Model::BulkUpdateRequest < Fumimi::Model
  include Fumimi::HasDTextFields
  def embed(embed, channel) # rubocop:disable Lint/UnusedMethodArgument
    embed.title = shortlink
    embed.url = url

    embed.author = Discordrb::Webhooks::EmbedAuthor.new(
      name: forum_topic.title,
      url: forum_post.url
    )

    embed.description = pretty_bur

    embed.footer = embed_footer
    embed.footer.text = "Status: #{status.titleize} | #{embed_footer.text}"

    embed
  end

  def pretty_bur
    lines = script.split("\n").compact
    body = lines.first(10).join("\n")
    body += "\n...and #{lines.size - 10} more lines." if lines.size > 10
    sanitize_for_discord(body)
  end
end
