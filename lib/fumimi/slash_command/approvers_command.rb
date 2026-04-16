require "fumimi/slash_command"

class Fumimi::SlashCommand::ApproversCommand < Fumimi::SlashCommand
  def self.name
    "approvers"
  end

  def self.description
    "Show a report for most active approvers."
  end

  def self.options
    [
      { type: OPTION_TYPES[:string], name: "tags", description: "Tag search string.", required: false },
    ]
  end

  def embeds
    [report.embed]
  end

  private

  def report
    Fumimi::Report::ApproverReport.new(booru: @booru, tags: tags, user: @event.user)
  end

  def tags
    arguments[:tags].to_s.split(/\s+/).reject(&:blank?)
  end
end
