require "fumimi/slash_command"

class Fumimi::SlashCommand::ForumTopicCommand < Fumimi::SlashCommand
  def self.name
    "topics"
  end

  def self.description
    "Do a topic search."
  end

  def self.options
    [
      # https://github.com/danbooru/danbooru/issues/6394
      # { type: OPTION_TYPES[:string], name: "contains", description: "Contains this string.", required: false },
      { type: OPTION_TYPES[:string], name: "creator", description: "Created by a user.", required: false },
      { type: OPTION_TYPES[:integer], name: "limit", description: "Max amount to return.", required: false, min_value: 1, max_value: 10 },
    ]
  end

  def embeds
    forum_posts.map(&:embed)
  end

  def forum_posts
    forum_post_ids = forum_topics.map { |t| t.original_post.id }
    raise Fumimi::Exceptions::NoResultsError if forum_post_ids.blank?

    forum_posts = @booru.forum_posts.index("search[id]": forum_post_ids.join(",")).reject(&:hidden?)
    raise Fumimi::Exceptions::NoResultsError if forum_posts.blank?

    forum_posts
  end

  def forum_topics
    query_params = {
      "search[is_private]": false,
      "search[order]": "id",
      limit: arguments[:limit] || 3,
      only: "id,original_post",
    }

    query_params["search[creator_name]"] = arguments[:creator] if arguments[:creator].present?
    @booru.forum_topics.index(**query_params)
  end
end
