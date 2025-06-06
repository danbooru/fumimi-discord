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
      #{by_level_table.prettified}
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

  def by_level_table
    queue_headers = ["By Level", "Posts", "%"]
    nonbuilder_percent = (nonbuilder_report.total_posts / total_posts.to_f) * 100
    builder_percent = (builder_report.total_posts / total_posts.to_f) * 100

    abovebuilder_total = total_posts - nonbuilder_report.total_posts - builder_report.total_posts
    abovebuilder_percent = 100 - nonbuilder_percent - builder_percent

    queue_rows = [
      ["unprivileged", nonbuilder_report.total_posts.to_fs(:delimited), "%.2f" % nonbuilder_percent],
      ["builder", builder_report.total_posts.to_fs(:delimited), "%.2f" % builder_percent],
      ["contrib", abovebuilder_total.to_fs(:delimited), "%.2f" % abovebuilder_percent],
    ]
    @by_level_table ||= Fumimi::DiscordTable.new(headers: queue_headers, rows: queue_rows)
  end

  def nonbuilder_report
    @nonbuilder_report ||= Fumimi::PostReport::UploadReport.new(@event, @booru, @tags, level: "<32")
  end

  def builder_report
    @builder_report ||= Fumimi::PostReport::UploadReport.new(@event, @booru, @tags, level: "32")
  end
end
