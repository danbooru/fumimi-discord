require "fumimi/slash_command"

class Fumimi::SlashCommand::BursCommand < Fumimi::SlashCommand
  def self.name
    "burs"
  end

  def self.description
    "Show a report on active Bulk Update Requests."
  end

  def embeds
    [report.embed]
  end

  def report
    Fumimi::Report::BulkUpdateRequestReport.new(booru: @booru, log: @log)
  end
end
