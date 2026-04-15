require "fumimi/event"

class Fumimi::Event::CommentEvent < Fumimi::Event
  def self.pattern
    /comment #([0-9]+)/i
  end

  def embeds_for(matches)
    query_parameters = { "search[id]": matches.join(",") }
    comments = @booru.comments.index(**query_parameters)
    comments.map { |comment| comment.create_embed(channel: @event.channel) }
  end
end
