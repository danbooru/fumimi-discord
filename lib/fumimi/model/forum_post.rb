require "danbooru/model/forum_post"
require "fumimi/model"

class Fumimi::Model::ForumPost < Danbooru::Model::ForumPost
  include Fumimi::Model

  def self.render_forum_posts(channel, forum_posts)
    forum_posts.each do |forum_post|
      channel.send_embed { |embed| forum_post.embed(embed, forum_post) }
    end
  end

  def embed(embed, forum_post)
    embed.title = forum_post.topic.title
    embed.url = forum_post.url

    embed.author = Discordrb::Webhooks::EmbedAuthor.new(
      name: forum_post.creator.at_name,
      url: forum_post.creator.url
    )

    embed.description = forum_post.pretty_body
    embed.footer = embed_footer
  end
end
