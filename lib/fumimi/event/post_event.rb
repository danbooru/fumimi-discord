require "fumimi/event"

class Fumimi::Event::PostEvent < Fumimi::Event
  def self.pattern
    /post #([0-9]+)/i
  end

  def embeds_for(matches)
    posts = @booru.posts.index(tags: "id:#{matches.join(",")}")
    posts.map { |post| post.embed(nsfw_channel: @event.channel.nsfw?) }
  end
end
