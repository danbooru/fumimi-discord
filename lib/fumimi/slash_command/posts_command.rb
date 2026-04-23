require "fumimi/slash_command"

class Fumimi::SlashCommand::PostsCommand < Fumimi::SlashCommand
  def self.name
    "posts"
  end

  def self.description
    "Do a post search."
  end

  def self.options
    [
      { type: OPTION_TYPES[:string], name: "tags", description: "Tags for the post.", required: false },
      { type: OPTION_TYPES[:integer], name: "limit", description: "Max amount to return.", required: false, min_value: 1, max_value: 10 },
    ]
  end

  def embeds
    posts = @booru.posts.index(tags: arguments[:tags], limit: arguments[:limit] || 3)
    posts.map { |post| post.embed(nsfw_channel: @event.channel.nsfw?) }
  end
end
