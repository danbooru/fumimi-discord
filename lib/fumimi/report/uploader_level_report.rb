class Fumimi::Report::UploaderLevelReport < Fumimi::Report::PostTableReport
  def embed_title
    "Uploader Report by Level"
  end

  def table_headers
    ["Level", "Uploads", "%"]
  end

  def table_rows
    levels_for_search.map do |each_level|
      uploads = each_level["posts"]
      percent = (uploads / total_posts.to_f) * 100

      [each_level["level"], uploads.to_fs(:delimited), "%.2f" % percent]
    end
  end

  def levels_for_search
    @levels_for_search ||= report.sort_by { |u| Fumimi::Model::User::Levels.const_get(u["level"].upcase.to_sym) }
  end

  def report_search_params
    {
      id: "posts",
      "search[from]": "2005-05-24",
      "search[to]": (Time.now + 1.year).strftime("%Y-%m-%d"),
      "search[group]": "uploader.level",
      "search[group_limit]": 25,
      "search[tags]": tag_string,
    }
  end
end
