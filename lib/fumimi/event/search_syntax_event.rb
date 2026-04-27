class Fumimi::Event::SearchSyntaxEvent < Fumimi::Event
  def self.pattern
    /{{ [^}]+ }}/x
  end

  def embeds_for(matches)
    posts = matches.map do |match|
      search = match[/[^{}]+/]
      limit = matches.length > 1 ? 1 : (match[/limit:(\d+)/, 1] || 3).to_i

      @booru.posts.index(limit: limit.clamp(1, 5), tags: search)
    end.flatten

    posts.map { |post| post.embed(nsfw_channel: @event.channel.nsfw?) }
  end
end
