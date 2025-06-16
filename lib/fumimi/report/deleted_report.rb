class Fumimi::PostReport::DeletedReport < Fumimi::PostReport
  def title
    "Status Report for: #{@tags.join(" ")}".gsub("_", "\\_")
  end

  def total_posts
    report.pluck("posts").sum
  end

  def headers
    %w[Deleted Posts %]
  end

  def rows
    report.map do |each_status|
      percent = (each_status["posts"] / total_posts.to_f) * 100

      [each_status["is_deleted"].to_s, each_status["posts"].to_fs(:delimited), "%.2f" % percent]
    end
  end

  def search_params
    {
      id: "posts",
      "search[from]": start_date,
      "search[to]": end_date,
      "search[group]": "is_deleted",
      "search[tags]": @tags.join(" "),
    }
  end
end
