class Fumimi::Report::PostStatsReport
  include Fumimi::HasDiscordEmbed

  def initialize(booru:, tags:)
    @booru = booru
    @tags = tags
  end

  def embed_title
    "Post Stats"
  end

  def embed_description
    if total_posts == 0
      <<~EOF.chomp
        #{tag_description}

        No posts under that search!
      EOF
    else
      <<~EOS
        #{tag_description}
        ```
        #{total_table.prettified}
        #{rating_report.table.prettified}
        #{status_report.table.prettified}
        #{by_level_report.table.prettified unless tag_string =~ /user:[^\b]+/}
        ```
      EOS
    end
  end

  def embed_timestamp
    Time.now
  end

  def tag_string
    @tags.join(" ").strip
  end

  def tag_description
    "Report for tags: `#{tag_string}`." if tag_string.present?
  end

  def total_posts
    rating_report.total_posts
  end

  def total_table
    @total_table ||= Fumimi::DiscordTable.new(headers: ["Total Posts", total_posts.to_fs(:delimited)], rows: [])
  end

  def rating_report
    @rating_report ||= Fumimi::Report::RatingReport.new(booru: @booru, tags: @tags)
  end

  def status_report
    @status_report ||= Fumimi::Report::DeletedReport.new(booru: @booru, tags: @tags)
  end

  def by_level_report
    @by_level_report ||= Fumimi::Report::UploaderLevelReport.new(booru: @booru, tags: @tags)
  end
end
