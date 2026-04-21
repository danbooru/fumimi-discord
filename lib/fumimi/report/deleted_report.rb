class Fumimi::Report::DeletedReport < Fumimi::Report::PostTableReport
  def embed_title
    "Status Report"
  end

  def table_headers
    %w[Status Posts %]
  end

  def table_rows
    report.map do |each_status|
      percent = (each_status["posts"] / total_posts.to_f) * 100

      [each_status["is_deleted"] ? "deleted" : "active", each_status["posts"].to_fs(:delimited), "%.2f" % percent]
    end
  end

  def total_posts
    report.pluck("posts").sum
  end

  def report_search_params
    {
      id: "posts",
      "search[from]": "2005-05-24",
      "search[to]": (Time.now + 1.year).strftime("%Y-%m-%d"),
      "search[group]": "is_deleted",
      "search[tags]": tag_string,
    }
  end
end
