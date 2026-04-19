require "fumimi/slash_command"

class Fumimi::SlashCommand::PostCountCommand < Fumimi::SlashCommand
  def self.name
    "count"
  end

  def self.description
    "Get a post count for a search."
  end

  def self.options
    [
      { type: OPTION_TYPES[:string], name: "tags", description: "Tags to search for.", required: false },
    ]
  end

  def message
    counts = @booru.post_counts.index(tags: "#{tags} -id:#{(0...9).map { rand(1..9) }.join}") # avoid cache
    "Post count#{pretty_tags}: #{counts.pretty}."
  end

  def tags
    arguments[:tags]
  end

  def pretty_tags
    return unless tags

    " for `#{tags}`"
  end
end
