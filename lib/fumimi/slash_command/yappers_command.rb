class Fumimi::SlashCommand::YappersCommand < Fumimi::SlashCommand
  def self.name
    "yappers"
  end

  def self.description
    "Show a ranking for top forum yappers."
  end

  def self.options
    [
      { type: OPTION_TYPES[:string], name: "time_range",
        description: "Custom time range. Default 1d. Examples: 1h, 2d, 1w, 1mo.", required: false },
      { type: OPTION_TYPES[:integer], name: "topic_id", description: "A topic ID.", required: false },
    ]
  end

  def embeds
    [report.embed]
  end

  def report
    Fumimi::Report::YappersReport.new(fumimi: @fumimi, range: range, topic_id: arguments[:topic_id], cache: @cache)
  end

  def range
    custom_range = arguments[:time_range].presence || "1d"

    Fumimi::TimeRangeParser.string_to_range(
      custom_range,
      min: 1.second,
      max: 1.month,
      raise_on_validation: true,
    )
  end
end
