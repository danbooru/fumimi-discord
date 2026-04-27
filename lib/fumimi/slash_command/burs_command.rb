class Fumimi::SlashCommand::BursCommand < Fumimi::SlashCommand
  def self.name
    "burs"
  end

  def self.description
    "Show a report on pending Bulk Update Requests."
  end

  def embeds
    [report.embed]
  end

  def report
    Fumimi::Report::BulkUpdateRequestReport.new(booru: @booru)
  end
end
