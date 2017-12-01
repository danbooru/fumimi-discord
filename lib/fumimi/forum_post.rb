require "danbooru/model/forum_post"
require "fumimi/model"

class Fumimi
  class ForumPost < Danbooru::Model::ForumPost
    include Fumimi::Model

    def self.render_forum_posts(channel, forum_posts, booru)
      creator_ids = forum_posts.map(&:creator_id).join(",")
      users = booru.users.search(id: creator_ids).group_by(&:id).transform_values(&:first)

      topic_ids = forum_posts.map(&:topic_id).join(",")
      forum_topics = booru.forum_topics.search(id: topic_ids).group_by(&:id).transform_values(&:first)

      forum_posts.each do |forum_post|
        user = users[forum_post.creator_id]
        topic = forum_topics[forum_post.topic_id]

        channel.send_embed { |embed| forum_post.embed(embed, topic, user) }
      end
    end

    def embed(embed, topic, user)
      embed.author = Discordrb::Webhooks::EmbedAuthor.new({
        name: user.at_name,
        url: user.url
      })

      embed.title = topic.title
      embed.url = url

      embed.description = pretty_body
      embed.footer = embed_footer
    end
  end
end
