class Fumimi::SlashCommand::UploadsByYearCommand < Fumimi::SlashCommand
  def self.name
    "uploads_by_year"
  end

  def self.description
    "Show posts by year for a tag search."
  end

  def self.options
    [
      { type: OPTION_TYPES[:string], name: "tags", description: "Tags to search for.", required: false },
    ]
  end

  def embeds
    [report.embed]
  end

  def report
    Fumimi::Report::UploadsByYearReport.new(booru: @booru, tags: tags)
  end

  def tags
    arguments[:tags].to_s.split(/\s+/).reject(&:blank?)
  end
end
