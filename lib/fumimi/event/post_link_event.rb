require "fumimi/event"

class Fumimi::Event::PostLinkEvent < Fumimi::Event
  def self.pattern
    %r{\b(?!https?://\w+\.donmai\.us/posts/\d+/\w+)https?://(?!testbooru)\w+\.donmai\.us/posts/(\d+)\b[^[:space:]]*}i
  end

  def embeds_for(matches)
    @event.message.suppress_embeds

    posts = @booru.posts.index(tags: "id:#{matches.join(",")}")
    posts.map { |post| post.embed(nsfw_channel: @event.channel.nsfw?) }
  end
end
