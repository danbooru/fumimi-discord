require "fumimi/model"

class Fumimi::Model::Comment < Fumimi::Model
  include Fumimi::HasDTextFields

  def embed(embed, channel)
    embed.title = shortlink
    embed.url = url

    embed.author = Discordrb::Webhooks::EmbedAuthor.new(
      name: creator.at_name,
      url: creator.url
    )

    embed.description = pretty_body
    embed.thumbnail = post.embed_thumbnail(channel.nsfw?)
    embed.footer = embed_footer
  end
end
