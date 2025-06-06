class Fumimi::PostReport::UploadReport < Fumimi::PostReport
  def title
    "Upload Report for: #{@tags.join(" ")}".gsub("_", "\\_")
  end

  def total_posts
    uploads_by_year.pluck("posts").sum
  end

  def headers
    %w[Year Uploads Rate]
  end

  def rows
    relevant_years.each_with_index.map do |each_year, index|
      prev_posts = relevant_years.dig(index + 1, "posts") || 0
      if index == 0
        rate = "?"
      elsif prev_posts < each_year["posts"]
        rate = "^"
      elsif prev_posts > each_year["posts"]
        rate = "▼"
      elsif prev_posts == each_year["posts"]
        rate = "-"
      end

      special_number = best_years.index(each_year["year"]) || 3
      special_number += 1
      special = special_number < 4 ? special_number.ordinalize : "   "

      [each_year["year"].to_s, each_year["posts"].to_fs(:delimited), "#{special} #{rate}"]
    end
  end

  def uploads_by_year
    @uploads_by_year ||= report.map do |each_year|
      each_year["year"] = each_year["date"].to_datetime.year
      each_year
    end
  end

  def first_year
    uploads_by_year.rindex { |each_year| each_year["posts"] != 0 }
  end

  def relevant_years
    uploads_by_year[..first_year]
  end

  def best_years
    uploads_by_year.sort_by { |each_year| each_year["posts"] }.reverse.pluck("year").first(3)
  end

  def search_params
    {
      id: "posts",
      "search[from]": start_date,
      "search[to]": end_date,
      "search[period]": "year",
      "search[tags]": @tags.join(" "),
      "search[uploader][level]": @level.presence,
    }
  end
end
