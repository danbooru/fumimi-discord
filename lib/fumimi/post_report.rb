class Fumimi::PostReport
  def initialize(event, booru, tags)
    @event = event
    @booru = booru
    @tags = tags
  end

  def send_embed(embed)
    embed.title = title
    embed.url = url
    embed.description = "-# Requested by <@#{@event.user.id}>\n#{description}"
    embed
  end

  def description
    if total_posts == 0
      "No posts under that search!"
    else
      table.to_s
    end
  end

  def table
    Fumimi::DiscordTable.new(headers: headers, rows: rows)
  end

  def url
    "#{@booru.url}/reports/posts?#{search_params.to_query}"
  end

  def total_posts
    @total_posts ||= @booru.counts.index(tags: @tags.join(" ")).counts.posts
  end

  def start_date
    "2005-05-24"
  end

  def end_date
    (Time.now + 1.day).strftime("%Y-%m-%d")
  end

  def report
    @report ||= @booru.post_reports.index(**search_params).as_json
  end
end
