require "fumimi/slash_command"

class Fumimi::SlashCommand::FutureCommand < Fumimi::SlashCommand
  def self.name
    "future"
  end

  def self.description
    "Predict future post milestones."
  end

  def embeds
    [report.embed]
  end

  def report
    Fumimi::Report::FutureReport.new(booru: @booru, cache: @cache)
  end
end
