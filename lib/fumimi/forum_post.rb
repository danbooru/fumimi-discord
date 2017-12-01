require "danbooru/forum_post"
require "fumimi/model"

class Fumimi
  class ForumPost < Danbooru::ForumPost
    include Fumimi::Model

    def self.render_forum_posts(channel, forum_posts, booru)
      creator_ids = forum_posts.map(&:creator_id).join(",")
      users = booru.users.search(id: creator_ids).group_by(&:id).transform_values(&:first)

      topic_ids = forum_posts.map(&:topic_id).join(",")
      forum_topics = booru.forum_topics.search(id: topic_ids).group_by(&:id).transform_values(&:first)

      forum_posts.each do |forum_post|
        user = users[forum_post.creator_id]
        topic = forum_topics[forum_post.topic_id]

        forum_post.send_embed(channel, topic, user)
      end
    end

    def send_embed(channel, topic, user)
      channel.send_embed do |embed|
        embed(embed, topic, user)
      end
    end

    def embed(embed, topic, user)
      embed.author = Discordrb::Webhooks::EmbedAuthor.new({
        name: "#{topic.title} (forum ##{id})",
        url: "#{booru.host}/forum_posts/#{id}"
      })

      embed.title = "@#{user.name}"
      embed.url = "#{booru.host}/users?name=#{user.name}"

      embed.description = pretty_body
      embed.footer = embed_footer
    end
  end
end
