require "fumimi/event"

class Fumimi::Event::CommentEvent < Fumimi::Event
  def self.pattern
    /comment #([0-9]+)/i
  end

  def self.model_for_link_capture
    "comments"
  end

  def embeds_for(matches)
    query_parameters = { "search[id]": matches.join(",") }
    comments = @booru.comments.index(**query_parameters)

    matches = matches.map(&:to_i)
    comments.sort_by! { |comment| matches.index(comment.id) || Float::INFINITY }
    comments.map { |comment| comment.embed(nsfw_channel: @event.channel.nsfw?) }
  end
end
