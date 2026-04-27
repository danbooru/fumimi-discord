class Fumimi::Model::ForumTopic < Fumimi::Model
  def hidden?
    min_level != "None"
  end

  def shortlink
    "topic ##{id}"
  end

  def all_posts
    (1..).each_with_object([]) do |page, forum_posts|
      page_posts = booru.forum_posts.index("search[topic_id]": id, page: page)
      break forum_posts if page_posts.empty?

      forum_posts.concat(page_posts)
    end
  end

  def self.latest_raffle_topic(booru)
    forum_posts = booru.forum_posts.index(
      "search[topic][title_matches]": "Platinum Raffle",
      "search[creator][level]": ">=#{Fumimi::Model::User::Levels::MODERATOR}",
      limit: 1,
    )
    forum_posts.first.topic
  end
end
