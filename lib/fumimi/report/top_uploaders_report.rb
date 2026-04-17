class Fumimi::Report::TopUploadersReport < Fumimi::Report::PostTableReport
  def embed_title
    "Uploader Report"
  end

  def table_headers
    ["Name", "Uploads", "%"]
  end

  def table_rows
    uploaders_for_search.map do |each_uploader|
      uploads = each_uploader["posts"]
      percent = (uploads / total_posts.to_f) * 100

      [each_uploader["uploader"], uploads.to_fs(:delimited), "%.2f" % percent]
    end
  end

  def uploaders_for_search
    @uploaders_for_search ||= report.sort_by { |u| u["posts"] / total_posts.to_f }.reverse
  end

  def report_search_params
    {
      id: "posts",
      "search[from]": "2005-05-24",
      "search[to]": (Time.now + 1.year).strftime("%Y-%m-%d"),
      "search[group]": "uploader",
      "search[group_limit]": 25,
      "search[tags]": tag_string,
    }
  end
end
