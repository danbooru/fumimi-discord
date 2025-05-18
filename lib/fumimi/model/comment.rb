require "danbooru/model/comment"
require "fumimi/model"

class Fumimi::Model::Comment < Danbooru::Model::Comment
  include Fumimi::Model

  def self.render_comments(channel, comments, booru)
    creator_ids = comments.map(&:creator_id).join(",")
    users = booru.users.search(id: creator_ids).index_by(&:id)

    post_ids = comments.map(&:post_id).join(",")
    posts = booru.posts.index(tags: "status:any id:#{post_ids}").index_by(&:id)

    comments.each do |comment|
      user = users[comment.creator_id]
      post = posts[comment.post_id]
      channel.send_embed { |embed| comment.embed(embed, channel, user, post) }
    end
  end

  def embed(embed, channel, user, post)
    embed.title = shortlink
    embed.url = url

    embed.author = Discordrb::Webhooks::EmbedAuthor.new(
      name: user.at_name,
      url: user.url
    )

    embed.description = pretty_body
    embed.thumbnail = post.embed_thumbnail(channel.nsfw?)
    embed.footer = embed_footer
  end
end
