require "danbooru/comment"
require "fumimi/model"

class Fumimi
  class Comment < Danbooru::Comment
    include Fumimi::Model

    def self.render_comments(channel, comments, booru)
      creator_ids = comments.map(&:creator_id).join(",")
      users = booru.users.search(id: creator_ids).group_by(&:id).transform_values(&:first)

      post_ids = comments.map(&:post_id).join(",")
      posts = booru.posts.index(tags: "status:any id:#{post_ids}").group_by(&:id).transform_values(&:first)

      comments.each do |comment|
        user = users[comment.creator_id]
        post = posts[comment.post_id]
        channel.send_embed { |embed| comment.embed(embed, channel, user, post) }
      end
    end

    def embed(embed, channel, user, post)
      embed.title = shortlink
      embed.url = url

      embed.author = Discordrb::Webhooks::EmbedAuthor.new({
        name: user.at_name,
        url: user.url
      })

      embed.description = pretty_body
      embed.thumbnail = post.embed_thumbnail(channel.name)
      embed.footer = embed_footer
    end
  end
end
