require "fumimi"

class Fumimi::UploadReport
  def initialize(booru, tags)
    @booru = booru
    @tags = tags
  end

  def upload_report
    message = "### [Upload Report for Search](<#{@booru.url}/reports/posts?#{upload_per_years_params.to_query}>)"
    message += " `#{@tags.join(" ")}`\n"

    report = uploads_by_year
    if report.all? { |y| y["posts"] == 0 }
      message += "No posts under that search!"
      return
    end

    first_year = report.rindex { |each_year| each_year["posts"] != 0 }

    message += <<~EOF.chomp
      ```
      +-------+----------------+
      | Year  | Uploads        |
      +-------+----------------+

    EOF

    report[..first_year].each_with_index do |each_year, index|
      year = each_year["year"]
      posts = each_year["posts"].to_fs(:delimited).ljust(12)

      prev_posts = report.dig(index + 1, "posts") || 0
      if index == 0
        rate = "?"
      elsif prev_posts < each_year["posts"]
        rate = "^"
      elsif prev_posts > each_year["posts"]
        rate = "▼"
      elsif prev_posts == each_year["posts"]
        rate = "-"
      end

      message += "| #{year}  | #{posts} #{rate} |\n"
    end

    message += <<~EOF.chomp
      +-------+----------------+
      ```
    EOF

    message
  end

  def uploader_report
    total = @booru.counts.index(tags: @tags).counts.posts

    message = "### [Uploader Report for Search](<#{@booru.url}/reports/posts?#{uploaders_per_search_params.to_query}>)"
    message += " `#{@tags.join(" ")}`\n"

    if total == 0
      message += "No posts under that search!"
      return
    end

    report = uploaders_by_search.sort_by { |u| u["posts"] / total.to_f }.reverse

    longest_name = report.pluck("uploader").max_by(&:length)
    n_s = "-" * longest_name.length

    message += <<~EOF.chomp
      ```
      +-#{n_s}-+---------+-------+
      | #{"Name".ljust(longest_name.length)} | Uploads | %     |
      +-#{n_s}-+---------+-------+

    EOF

    report.each do |each_uploader|
      name = each_uploader["uploader"].ljust(longest_name.length)
      uploads = each_uploader["posts"]
      percent = (uploads / total.to_f) * 100

      uploads = uploads.to_fs(:delimited).ljust(7)
      percent = ("%.2f" % percent).ljust(5)

      message += "| #{name} | #{uploads} | #{percent} |\n"
    end

    message += <<~EOF.chomp
      +-#{n_s}-+---------+-------+
      ```
    EOF

    message
  end

  def uploads_by_year
    post_report = @booru.post_reports.index(**upload_per_years_params)

    post_report.as_json.map do |each_year|
      each_year["year"] = each_year["date"].to_datetime.year
      each_year
    end
  end

  def upload_per_years_params
    start_date = "2005-05-24"
    end_date = Time.now.strftime("%Y-%m-%d")

    {
      id: "posts",
      "search[from]": start_date,
      "search[to]": end_date,
      "search[period]": "year",
      "search[tags]": @tags.join(" "),
    }
  end

  def uploaders_by_search
    post_report = @booru.post_reports.index(**uploaders_per_search_params)
    post_report.as_json
  end

  def uploaders_per_search_params
    start_date = "2005-05-24"
    end_date = Time.now.strftime("%Y-%m-%d")

    {
      id: "posts",
      "search[from]": start_date,
      "search[to]": end_date,
      "search[group]": "uploader",
      "search[group_limit]": 25,
      "search[tags]": @tags.join(" "),
    }
  end
end
