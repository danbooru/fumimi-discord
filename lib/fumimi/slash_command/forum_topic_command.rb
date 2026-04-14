require "fumimi/slash_command"

class Fumimi::SlashCommand::ForumTopicCommand < Fumimi::SlashCommand
  def self.name
    "topics"
  end

  def self.description
    "Do a topic search."
  end

  def self.options(cmd)
    cmd.integer("limit", "Max amount to return.", min_value: 1, max_value: 10)
    cmd.string("creator", "Name of the forum topic creator.")
    # cmd.string("contains", "A string to search.") # https://github.com/danbooru/danbooru/issues/6394
  end

  def query_params
    query_params = {
      "search[is_private]": false,
      "search[order]": "id",
      limit: arguments[:limit] || 3,
      only: "id,original_post",
    }

    query_params["search[creator_name]"] = arguments[:creator] if arguments[:creator].present?

    query_params
  end

  def embeds
    forum_topics = @booru.forum_topics.index(**query_params)
    forum_post_ids = forum_topics.map { |t| t.original_post.id }

    raise Fumimi::Exceptions::NoResultsError if forum_post_ids.blank?

    forum_posts = @booru.forum_posts.index("search[id]": forum_post_ids.join(","))

    raise Fumimi::Exceptions::NoResultsError if forum_posts.blank?

    forum_posts.map do |forum_post|
      next if forum_post.hidden?

      forum_post.create_embed(channel)
    end
  end
end
