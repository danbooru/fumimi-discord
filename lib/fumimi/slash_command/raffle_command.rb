require "fumimi/slash_command"

class Fumimi::SlashCommand::RaffleCommand < Fumimi::SlashCommand
  def self.name
    "raffle"
  end

  def self.description
    "Show stats for the latest raffle."
  end

  def embeds
    [report.embed]
  end

  def report
    Fumimi::RaffleReport.new(booru: @booru, cache: @cache)
  end
end
