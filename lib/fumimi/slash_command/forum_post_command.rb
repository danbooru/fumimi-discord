require "fumimi/slash_command"

class Fumimi::SlashCommand::ForumPostCommand < Fumimi::SlashCommand
  def self.name
    "forum"
  end

  def self.description
    "Do a forum search."
  end

  def self.options(cmd)
    cmd.integer("limit", "Max amount to return.", min_value: 1, max_value: 10)
    cmd.string("creator", "Name of the forum post creator.")
    cmd.string("contains", "A string to search.")
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

  def embeds
    forum_posts = @booru.forum_posts.index(**query_params)

    raise Fumimi::Exceptions::NoResultsError if forum_posts.blank?

    forum_posts.map do |forum_post|
      next if forum_post.hidden?

      forum_post.create_embed(channel)
    end
  end
end
