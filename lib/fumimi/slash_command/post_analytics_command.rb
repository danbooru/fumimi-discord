class Fumimi::SlashCommand::PostAnalyticsCommand < Fumimi::SlashCommand
  def self.name
    "searches"
  end

  def self.description
    "Check analytics for tag searches."
  end

  def self.options
    [
      { type: OPTION_TYPES[:string], name: "tags", description: "List of searched tags.", required: false },
      { type: OPTION_TYPES[:string], name: "time_range",
        description: "Custom time range. Default 1d. Examples: 1h, 2d, 1w, 1mo.", required: false },
    ]
  end

  def embeds
    [report.embed]
  end

  def report
    Fumimi::Report::PostAnalyticsReport.new(tags: tags, range: range, fumimi: @fumimi)
  end

  def tags
    arguments[:tags].to_s.split(/\s+/).reject(&:blank?)
  end

  def range
    is_staff = @event.user.roles.any? { |r| %w[mod admin].include?(r.name.downcase) }
    custom_range = arguments[:time_range].presence || "1d"

    Fumimi::TimeRangeParser.string_to_range(
      custom_range,
      min: 1.second,
      max: is_staff ? 1.month : 1.day,
      raise_on_validation: true,
    )
  end
end
