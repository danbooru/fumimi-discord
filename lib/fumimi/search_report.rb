class Fumimi::SearchReport
  def initialize(event, booru, tags)
    @event = event
    @booru = booru
    @tags = tags
  end

  def send_embed(embed)
    embed.title = title
    embed.description = "-# Requested by <@#{@event.user.id}>\n#{description}"
    embed
  end

  def title
    "Stats for: #{@tags.join(" ")}".gsub("_", "\\_")
  end

  def description
    return "No posts under that search!" if total_posts == 0

    <<~EOS
      ```
      #{total_table.prettified}
      #{rating_report.table.prettified}
      #{status_report.table.prettified}
      #{by_level_report.table.prettified unless @tags.join(" ").strip =~ /user:[^\b]+/}
      ```
    EOS
  end

  def total_posts
    rating_report.total_posts
  end

  def total_table
    @total_table ||= Fumimi::DiscordTable.new(headers: ["Total Posts", total_posts.to_fs(:delimited)], rows: [])
  end

  def rating_report
    @rating_report ||= Fumimi::PostReport::RatingReport.new(@event, @booru, @tags)
  end

  def status_report
    @status_report ||= Fumimi::PostReport::DeletedReport.new(@event, @booru, @tags)
  end

  def by_level_report
    @by_level_report ||= Fumimi::PostReport::UploaderLevelReport.new(@event, @booru, @tags)
  end
end
