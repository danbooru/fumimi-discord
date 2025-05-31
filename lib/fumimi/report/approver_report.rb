class Fumimi::PostReport::ApproverReport < Fumimi::PostReport
  def title
    "Approver Report for: #{@tags.join(" ")}".gsub("_", "\\_")
  end

  def description
    return "No posts under that search!" if total_posts == 0

    sep = "-" * padding

    description = <<~EOF.chomp
      ```
      +-#{sep}-+-----------+-------+
      | #{"Name".ljust(padding)} | Approvals | %     |
      +-#{sep}-+-----------+-------+

    EOF

    approvers_for_search.each do |each_uploader|
      name = each_uploader["approver"].ljust(padding)
      approvals = each_uploader["posts"]
      percent = (approvals / total_posts.to_f) * 100

      approvals = approvals.to_fs(:delimited).ljust(9)
      percent = ("%.2f" % percent).ljust(5)

      description << "| #{name} | #{approvals} | #{percent} |\n"
    end

    description << <<~EOF.chomp
      +-#{sep}-+-----------+-------+
      ```
    EOF

    description
  end

  def approvers_for_search
    @approvers_for_search ||= report.sort_by { |u| u["posts"] / total_posts.to_f }.reverse
  end

  def padding
    @padding ||= approvers_for_search.pluck("approver").max_by(&:length).length
  end

  def search_params
    {
      id: "posts",
      "search[from]": start_date,
      "search[to]": end_date,
      "search[group]": "approver",
      "search[group_limit]": 25,
      "search[tags]": @tags.join(" "),
    }
  end
end
