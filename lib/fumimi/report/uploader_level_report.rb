class Fumimi::PostReport::UploaderLevelReport < Fumimi::PostReport
  def title
    "Uploader Report by Level for: #{@tags.join(" ")}".gsub("_", "\\_")
  end

  def headers
    ["Level", "Uploads", "%"]
  end

  def rows
    levels_for_search.map do |each_level|
      uploads = each_level["posts"]
      percent = (uploads / total_posts.to_f) * 100

      [each_level["level"], uploads.to_fs(:delimited), "%.2f" % percent]
    end
  end

  def levels_for_search
    @levels_for_search ||= report.sort_by { |u| Fumimi::Model::Post::Levels.const_get(u["level"].upcase.to_sym) }
  end

  def search_params
    {
      id: "posts",
      "search[from]": start_date,
      "search[to]": end_date,
      "search[group]": "uploader.level",
      "search[group_limit]": 25,
      "search[tags]": @tags.join(" "),
    }
  end
end
