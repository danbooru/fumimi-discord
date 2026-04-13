require "fumimi/event"

class Fumimi::Event::ForumPostEvent < Fumimi::Event
  def self.pattern
    /forum #([0-9]+)/i
  end

  def embeds_for(matches)
    query_parameters = { "search[id]": matches.join(",") }
    forum_posts = @booru.forum_posts.index(**query_parameters)

    forum_posts.sort_by { |fp| matches.index(fp.id) || Float::INFINITY }

    forum_posts.map do |forum_post|
      next if forum_post.hidden?

      forum_post.create_embed(channel)
    end
  end
end
