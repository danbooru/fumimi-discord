require "fumimi/slash_command"

class Fumimi::SlashCommand::CommentCommand < Fumimi::SlashCommand
  def self.name
    "comments"
  end

  def self.description
    "Do a comment search."
  end

  def self.options
    [
      { type: OPTION_TYPES[:string], name: "contains", description: "Contains this string.", required: false },
      { type: OPTION_TYPES[:string], name: "creator", description: "Created by a user.", required: false },
      { type: OPTION_TYPES[:string], name: "post_tags", description: "Tags for the post.", required: false },
      { type: OPTION_TYPES[:integer], name: "limit", description: "Max amount to return.", required: false, min_value: 1, max_value: 10 },
    ]
  end

  def embeds
    comments.map { |comment| comment.embed(nsfw_channel: @event.channel.nsfw?) }
  end

  def comments
    comments = @booru.comments.index(**query_params)
    raise Fumimi::Exceptions::NoResultsError if comments.blank?

    comments
  end

  def query_params
    query_params = {
      limit: arguments[:limit] || 3,
    }

    if arguments[:contains].present?
      contains = arguments[:contains].strip("*")
      query_params["search[body_ilike]"] = "*#{contains}*"
    end

    query_params["search[creator_name]"] = arguments[:creator] if arguments[:creator].present?
    query_params["search[post_tags_match]"] = arguments[:post_tags] if arguments[:post_tags].present?

    query_params
  end
end
