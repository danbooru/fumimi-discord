class Fumimi::PostReport::UploadReport < Fumimi::PostReport
  def title
    "Upload Report for: #{@tags.join(" ")}".gsub("_", "\\_")
  end

  def description
    return "No posts under that search!" if uploads_by_year.all? { |y| y["posts"] == 0 }

    description = <<~EOF.chomp
      ```
      +-------+------------------+
      | Year  | Uploads          |
      +-------+------------------+

    EOF

    relevant_years.each_with_index do |each_year, index|
      year = each_year["year"]
      posts = each_year["posts"].to_fs(:delimited).ljust(10)

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

      special_number = best_years.index(year) || 3
      special_number += 1
      special = special_number < 4 ? special_number.ordinalize : "   "

      description << "| #{year}  | #{posts} #{special} #{rate} |\n"
    end

    description << <<~EOF.chomp
      +-------+------------------+
      ```
    EOF

    description
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
    }
  end
end
