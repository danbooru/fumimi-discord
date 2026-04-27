class Fumimi::SlashCommand::TopUploadersCommand < Fumimi::SlashCommand
  def self.name
    "top_uploaders"
  end

  def self.description
    "Show top uploaders for a tag search."
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
    Fumimi::Report::TopUploadersReport.new(booru: @booru, tags: tags)
  end

  def tags
    arguments[:tags].to_s.split(/\s+/).reject(&:blank?)
  end
end
