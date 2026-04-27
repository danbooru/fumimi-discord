require "fumimi/slash_command"

class Fumimi::SlashCommand::RafflepickCommand < Fumimi::SlashCommand
  def self.name
    "rafflepick"
  end

  def self.description
    "Pick winners for the latest raffle."
  end

  def self.options
    [
      { type: OPTION_TYPES[:integer], name: "winner_count", description: "Number of winners.", required: true, min_value: 1, max_value: 20 }, # rubocop:disable Layout/LineLength
    ]
  end

  def embeds
    [report.embed]
  end

  def report
    Fumimi::Report::RaffleReport.new(booru: @booru, cache: @cache, winner_count: winner_count)
  end

  def winner_count
    count = arguments[:winner_count].to_i
    count.clamp(1, 20)
  end
end
