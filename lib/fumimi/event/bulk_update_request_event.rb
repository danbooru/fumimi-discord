class Fumimi::Event::BulkUpdateRequestEvent < Fumimi::Event
  def self.pattern
    /bur #([0-9]+)/i
  end

  def self.model_for_link_capture
    "bulk_update_requests"
  end

  def embeds_for(matches)
    query_parameters = { "search[bulk_update_request][id]": matches.join(",") }
    forum_posts = @booru.forum_posts.index(**query_parameters)

    matches = matches.map(&:to_i)
    forum_posts.sort_by! { |fp| matches.index(fp.bulk_update_request.id) || Float::INFINITY }
    forum_posts.reject(&:hidden?).map(&:embed)
  end
end
