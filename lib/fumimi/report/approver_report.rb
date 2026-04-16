class Fumimi::Report::ApproverReport < Fumimi::Report::PostTableReport
  def tag_string
    tags = @tags + ["approver:any"]
    tags.join(" ")
  end

  def table_headers
    ["Name", "Approvals", "%"]
  end

  def table_rows
    approvers_for_search.map do |each_approver|
      percent = (each_approver["posts"] / total_posts.to_f) * 100

      [each_approver["approver"], each_approver["posts"].to_fs(:delimited), "%.2f" % percent]
    end
  end

  def approvers_for_search
    @approvers_for_search ||= report.sort_by { |u| u["posts"] / total_posts.to_f }.reverse
  end

  def report_search_params
    {
      id: "posts",
      "search[from]": "2005-05-24",
      "search[to]": (Time.now + 1.year).strftime("%Y-%m-%d"),
      "search[group]": "approver",
      "search[group_limit]": 25,
      "search[tags]": tag_string,
    }
  end
end
