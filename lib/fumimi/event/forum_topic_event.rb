class Fumimi::Event::ForumTopicEvent < Fumimi::Event
  def self.pattern
    /topic #([0-9]+)/i
  end

  def self.model_for_link_capture
    "forum_topics"
  end

  def embeds_for(matches)
    forum_topics = @booru.forum_topics.index("search[id]": matches.join(","),
                                             "search[is_private]": false,
                                             only: "id,original_post")

    matches = matches.map(&:to_i)
    forum_topics.sort_by! { |ft| matches.index(ft.id) || Float::INFINITY }
    forum_post_ids = forum_topics.map { |t| t.original_post.id }

    return [] if forum_post_ids.blank?

    query_parameters = { "search[id]": forum_post_ids.join(",") }
    forum_posts = @booru.forum_posts.index(**query_parameters)
    forum_posts.reject(&:hidden?).map(&:embed)
  end
end
