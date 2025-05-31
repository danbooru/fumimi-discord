class Fumimi::PostReport::ApproverReport < Fumimi::PostReport
  def title
    "Approver Report for: #{@tags.join(" ")}".gsub("_", "\\_")
  end

  def headers
    ["Name", "Approvals", "%"]
  end

  def rows
    approvers_for_search.map do |each_approver|
      name = each_approver["approver"]
      approvals = each_approver["posts"]
      percent = (approvals / total_posts.to_f) * 100

      approvals = approvals.to_fs(:delimited)
      percent = ("%.2f" % percent)

      [name, approvals, percent]
    end
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
