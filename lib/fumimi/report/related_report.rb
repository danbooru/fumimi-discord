class Fumimi::RelatedReport
  include Fumimi::HasDiscordEmbed

  def initialize(booru:, tags:, category: nil)
    @booru = booru
    @tags = tags
    @category = category
  end

  def embed_title
    category_name = @category.nil? ? "tags" : "#{@category} tags"
    "Related #{category_name.titleize} Report"
  end

  def embed_description
    <<~EOF.chomp
      #{tag_description}
      #{table}
    EOF
  end

  def tag_string
    @tags.join(" ").strip
  end

  def tag_description
    return "" if tag_string.blank?

    "Report for tags: `%s`." % tag_string if tag_string
  end

  def table
    Fumimi::DiscordTable.new(headers: table_headers, rows: table_rows)
  end

  def table_headers
    %w[Name Frequency]
  end

  def table_rows
    related_tags.map do |each_tag|
      percent = each_tag["frequency"] * 100
      [each_tag.dig("tag", "name"), "%.2f" % percent]
    end
  end

  def url
    "#{@booru.url}/related_tag?#{search_params.except(:limit).to_query}"
  end

  def related_tags
    report["related_tags"].to_a
  end

  def report
    @report ||= @booru.related_tags.index(**search_params).as_json
  end

  def search_params
    {
      limit: 25,
      "search[category]": @category,
      "search[query]": tag_string,
    }
  end
end
