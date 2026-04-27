class Fumimi::SlashCommand::ForumPostCommand < Fumimi::SlashCommand
  def self.name
    "forum"
  end

  def self.description
    "Do a forum search."
  end

  def self.options
    [
      { type: OPTION_TYPES[:string], name: "contains", description: "Contains this string.", required: false },
      { type: OPTION_TYPES[:string], name: "creator", description: "Created by a user.", required: false },
      { type: OPTION_TYPES[:integer], name: "limit", description: "Max amount to return.", required: false, min_value: 1, max_value: 10 },
    ]
  end

  def embeds
    forum_posts.map(&:embed)
  end

  def forum_posts
    @booru.forum_posts.index(**query_params).reject(&:hidden?)
  end

  def query_params
    query_params = {
      "search[topic][is_private]": false,
      limit: arguments[:limit] || 3,
    }

    if arguments[:contains].present?
      contains = arguments[:contains].strip("*")
      query_params["search[body_ilike]"] = "*#{contains}*"
    end

    query_params["search[creator_name]"] = arguments[:creator] if arguments[:creator].present?

    query_params
  end
end
