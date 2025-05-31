class Fumimi::PostReport
  def initialize(booru, tags)
    @booru = booru
    @tags = tags
  end

  def send_embed(embed)
    embed.title = title
    embed.url = url
    embed.description = description
    embed
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
    Time.now.strftime("%Y-%m-%d")
  end

  def report
    @report ||= @booru.post_reports.index(**search_params).as_json
  end
end
