class Fumimi::Report::RatingReport < Fumimi::Report::PostTableReport
  def embed_title
    "Rating Report"
  end

  def table_headers
    %w[Rating Posts %]
  end

  def table_rows
    report.sort_by { |r| sort_order.index(r["rating"]) }.map do |each_rating|
      percent = (each_rating["posts"] / total_posts.to_f) * 100
      [each_rating["rating"].upcase, each_rating["posts"].to_fs(:delimited), "%.2f" % percent]
    end
  end

  def total_posts
    report.pluck("posts").sum
  end

  def sort_order
    %w[g s q e]
  end

  def report_search_params
    {
      id: "posts",
      "search[from]": "2005-05-24",
      "search[to]": (Time.now + 1.year).strftime("%Y-%m-%d"),
      "search[group]": "rating",
      "search[tags]": tag_string,
    }
  end
end
