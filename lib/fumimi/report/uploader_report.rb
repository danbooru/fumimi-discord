class Fumimi::PostReport::UploaderReport < Fumimi::PostReport
  def title
    "Uploader Report for: #{@tags.join(" ")}".gsub("_", "\\_")
  end

  def headers
    ["Name", "Uploads", "%"]
  end

  def rows
    uploaders_for_search.map do |each_uploader|
      uploads = each_uploader["posts"]
      percent = (uploads / total_posts.to_f) * 100

      [each_uploader["uploader"], uploads.to_fs(:delimited), "%.2f" % percent]
    end
  end

  def uploaders_for_search
    @uploaders_for_search ||= report.sort_by { |u| u["posts"] / total_posts.to_f }.reverse
  end

  def search_params
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
