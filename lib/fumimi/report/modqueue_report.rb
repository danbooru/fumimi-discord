class Fumimi::Report::ModQueueReport < Fumimi::Report::PostTableReport
  def tag_string
    tags = @tags + ["is:modqueue"]
    tags.join(" ")
  end

  def embed_description
    <<~EOS
      ### Total pending posts: [#{total_posts}](#{modqueue_link_for("")})
      ### New: [#{total_posts - appealed_posts - flagged_posts}](#{modqueue_link_for("is:modqueue -is:flagged -is:appealed")}), Appealed: [#{appealed_posts}](#{modqueue_link_for("is:appealed")}), Flagged: [#{flagged_posts}](#{modqueue_link_for("is:flagged")})

      Top users by pending uploads:
      #{uploader_list}

      Quick links:
      - [Pending posts by non-builders](#{modqueue_link_for(nil)}?search[uploader][level]=<32)
      - [Pending posts by builders](#{modqueue_link_for(nil)}?search[uploader][level]=32)
      - [Pending posts by unres](#{modqueue_link_for(nil)}?search[uploader][level]=>32)
    EOS
  end

  def appealed_posts
    @appealed_posts ||= @booru.counts.index(tags: "is:appealed").counts.posts
  end

  def flagged_posts
    @flagged_posts ||= @booru.counts.index(tags: "is:flagged").counts.posts
  end

  def modqueue_link_for(search)
    link = "#{@booru.url}/modqueue"
    link += "?search[tags]=#{CGI.escape(search)}" if search
    link
  end

  def uploader_list
    uploaders.first(10).map do |uploader|
      modq_link = modqueue_link_for("user:#{uploader["uploader"].tr(" ", "_")}")
      "- [#{uploader["uploader"]}](#{modq_link}): #{uploader["posts"]}"
    end.join("\n")
  end

  def uploaders
    @uploaders ||= report.sort_by { |u| u["posts"] / total_posts.to_f }.reverse
  end

  def report_search_params
    {
      id: "posts",
      "search[from]": "2005-05-24",
      "search[to]": (Time.now + 1.year).strftime("%Y-%m-%d"),
      "search[group]": "uploader",
      "search[group_limit]": 25,
      "search[tags]": tag_string,
      "search[uploader][level]": @level.presence,
    }
  end
end
