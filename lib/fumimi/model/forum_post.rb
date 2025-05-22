require "fumimi/model"

class Fumimi::Model::ForumPost < Fumimi::Model
  include Fumimi::HasDTextFields

  def embed(embed, channel) # rubocop:disable Lint/UnusedMethodArgument
    embed.title = topic.title
    embed.url = url

    embed.author = Discordrb::Webhooks::EmbedAuthor.new(
      name: creator.at_name,
      url: creator.url
    )

    embed.description = pretty_body
    embed.footer = embed_footer
  end
end
