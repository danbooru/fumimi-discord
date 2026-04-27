require "fumimi/slash_command"

class Fumimi::SlashCommand::RelatedCommand < Fumimi::SlashCommand
  def self.name
    "related_tags"
  end

  def self.description
    "List related tags."
  end

  def self.options
    [
      { type: OPTION_TYPES[:string], name: "tags", description: "Tags to search for.", required: true },
      { type: OPTION_TYPES[:string], name: "category", description: "Tag category (general, character, copyright, artist, meta).", required: false }, # rubocop:disable Layout/LineLength
    ]
  end

  def embeds
    [report.embed]
  end

  def report
    Fumimi::Report::RelatedReport.new(booru: @booru, tags: tags, category: category)
  end

  def tags
    arguments[:tags].to_s.split(/\s+/).reject(&:blank?)
  end

  def category
    category = arguments[:category]
    return category unless category

    normalized = Fumimi::TagCategory.category_map[category.delete_suffix("s")]
    raise Fumimi::Exceptions::CommandArgumentError, "Unknown category: `#{category}`." unless normalized

    normalized
  end
end
