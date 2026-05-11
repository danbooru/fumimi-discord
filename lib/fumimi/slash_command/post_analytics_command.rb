class Fumimi::SlashCommand::PostAnalyticsCommand < Fumimi::SlashCommand
  def self.name
    "searches"
  end

  def self.description
    "Check analytics for tag searches."
  end

  def self.options
    [
      { type: OPTION_TYPES[:string], name: "tags", description: "List of searched tags.", required: false, autocomplete: true },
      { type: OPTION_TYPES[:string], name: "time_range",
        description: "Custom time range. Default 1d. Examples: 1h, 2d, 1w, 1mo.", required: false },
    ]
  end

  def embeds
    [report.embed]
  end

  def report
    Fumimi::Report::PostAnalyticsReport.new(tags: tags, since: since, fumimi: @fumimi)
  end

  def tags
    arguments[:tags].to_s.split(/\s+/).reject(&:blank?)
  end

  def since
    time_range = arguments[:time_range].presence || "1d"
    Fumimi::TimeRangeParser.string_to_range(time_range)
  end
end
