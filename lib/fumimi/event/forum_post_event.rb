require "fumimi/event"

class Fumimi::Event::ForumPostEvent < Fumimi::Event
  def self.pattern
    /forum #([0-9]+)/i
  end

  def self.model_for_link_capture
    "forum_posts"
  end

  def embeds_for(matches)
    query_parameters = { "search[id]": matches.join(",") }
    forum_posts = @booru.forum_posts.index(**query_parameters)

    matches = matches.map(&:to_i)
    forum_posts.sort_by! { |forum| matches.index(forum.id) || Float::INFINITY }
    forum_posts.reject(&:hidden?).map(&:embed)
  end
end
