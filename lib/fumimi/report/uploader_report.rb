class Fumimi::PostReport::UploaderReport < Fumimi::PostReport
  def title
    "Uploader Report for: #{@tags.join(" ")}".gsub("_", "\\_")
  end

  def description
    return "No posts under that search!" if total_posts == 0

    sep = "-" * padding

    description = <<~EOF.chomp
      ```
      +-#{sep}-+---------+-------+
      | #{"Name".ljust(padding)} | Uploads | %     |
      +-#{sep}-+---------+-------+

    EOF

    uploaders_for_search.each do |each_uploader|
      name = each_uploader["uploader"].ljust(padding)
      uploads = each_uploader["posts"]
      percent = (uploads / total_posts.to_f) * 100

      uploads = uploads.to_fs(:delimited).ljust(7)
      percent = ("%.2f" % percent).ljust(5)

      description << "| #{name} | #{uploads} | #{percent} |\n"
    end

    description << <<~EOF.chomp
      +-#{sep}-+---------+-------+
      ```
    EOF

    description
  end

  def uploaders_for_search
    @uploaders_for_search ||= report.sort_by { |u| u["posts"] / total_posts.to_f }.reverse
  end

  def padding
    @padding ||= uploaders_for_search.pluck("uploader").max_by(&:length).length
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
