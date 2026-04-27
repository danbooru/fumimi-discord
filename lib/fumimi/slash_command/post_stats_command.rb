require "fumimi/slash_command"

class Fumimi::SlashCommand::PostStatsCommand < Fumimi::SlashCommand
  def self.name
    "post_stats"
  end

  def self.description
    "Show statistics about posts."
  end

  def self.options
    [
      { type: OPTION_TYPES[:string], name: "tags", description: "Tags to search for.", required: false },
    ]
  end

  def embeds
    [report.embed]
  end

  def report
    Fumimi::Report::PostStatsReport.new(booru: @booru, tags: tags)
  end

  def tags
    arguments[:tags].to_s.split(/\s+/).reject(&:blank?)
  end
end
