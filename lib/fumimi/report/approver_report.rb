class Fumimi::PostReport::ApproverReport < Fumimi::PostReport
  def title
    "Approver Report for: #{@tags.join(" ")}".gsub("_", "\\_")
  end

  def total_posts
    tags = @tags + ["approver:any"]
    @total_posts ||= @booru.counts.index(tags: tags.join(" ")).counts.posts
  end

  def headers
    ["Name", "Approvals", "%"]
  end

  def rows
    approvers_for_search.map do |each_approver|
      percent = (each_approver["posts"] / total_posts.to_f) * 100

      [each_approver["approver"], each_approver["posts"].to_fs(:delimited), "%.2f" % percent]
    end
  end

  def approvers_for_search
    @approvers_for_search ||= report.sort_by { |u| u["posts"] / total_posts.to_f }.reverse
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
