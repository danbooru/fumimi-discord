class Fumimi::RelatedReport
  def self.category_map
    {
      "gen" => "general",
      "general" => "general",
      "char" => "character",
      "character" => "character",
      "copy" => "copyright",
      "copyright" => "copyright",
      "art" => "artist",
      "artist" => "artist",
      "meta" => "meta",
    }
  end

  def initialize(event, booru, tags)
    @event = event
    @booru = booru
    @category = self.class.category_map[tags.first&.downcase&.delete_suffix("s")]
    @tags = @category.present? ? tags[1..] : tags
  end

  def send_embed(embed)
    embed.title = title
    embed.url = url
    embed.description = "-# Requested by <@#{@event.user.id}>\n#{description}"
    embed
  end

  def title
    category_name = @category.nil? ? "tags" : "#{@category} tags"
    "Related #{category_name} for: #{@tags.join(" ")}".gsub("_", "\\_")
  end

  def description
    return "No tags under that search!" if rows.empty?

    table.to_s
  end

  def table
    Fumimi::DiscordTable.new(headers: headers, rows: rows)
  end

  def headers
    %w[Name Frequency]
  end

  def rows
    related_tags.map do |each_tag|
      percent = each_tag["frequency"] * 100
      [each_tag.dig("tag", "name"), "%.2f" % percent]
    end
  end

  def url
    "#{@booru.url}/related_tag?#{search_params.except(:limit).to_query}"
  end

  def report
    @report ||= @booru.related_tags.index(**search_params).as_json
  end

  def related_tags
    report["related_tags"].to_a
  end

  def search_params
    {
      limit: 25,
      "search[category]": @category,
      "search[query]": @tags.join(" "),
    }
  end
end
