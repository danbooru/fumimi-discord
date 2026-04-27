class Fumimi::SlashCommand::ModQueueCommand < Fumimi::SlashCommand
  def self.name
    "modqueue"
  end

  def self.description
    "Show modqueue stats."
  end

  def embeds
    [report.embed]
  end

  def report
    Fumimi::Report::ModQueueReport.new(booru: @booru, tags: [])
  end
end
