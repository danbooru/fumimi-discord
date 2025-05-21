require "fumimi/model"

class Fumimi::Model::Comment < Fumimi::Model
  include Fumimi::HasDTextFields

  def self.render_comments(channel, comments)
    comments.each do |comment|
      channel.send_embed { |embed| comment.embed(embed, comment, channel) }
    end
  end

  def embed(embed, comment, channel)
    embed.title = shortlink
    embed.url = url

    embed.author = Discordrb::Webhooks::EmbedAuthor.new(
      name: comment.creator.at_name,
      url: comment.creator.url
    )

    embed.description = pretty_body
    embed.thumbnail = comment.post.embed_thumbnail(channel.nsfw?)
    embed.footer = embed_footer
  end
end
