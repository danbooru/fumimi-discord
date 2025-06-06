class Fumimi::PostReport::RatingReport < Fumimi::PostReport
  def title
    "Rating Report for: #{@tags.join(" ")}".gsub("_", "\\_")
  end

  def total_posts
    report.pluck("posts").sum
  end

  def headers
    %w[Rating Posts %]
  end

  def rows
    report.sort_by { |r| sort_order.index(r["rating"]) }.map do |each_rating|
      percent = (each_rating["posts"] / total_posts.to_f) * 100
      [each_rating["rating"].upcase, each_rating["posts"].to_fs(:delimited), "%.2f" % percent]
    end
  end

  def sort_order
    %w[g s q e]
  end

  def search_params
    {
      id: "posts",
      "search[from]": start_date,
      "search[to]": end_date,
      "search[group]": "rating",
      "search[tags]": @tags.join(" "),
      "search[uploader][level]": @level.presence,
    }
  end
end
