require "fumimi/event"

class Fumimi::Event::UserEvent < Fumimi::Event
  def self.pattern
    /user #([0-9]+)/i
  end

  def self.model_for_link_capture
    "users"
  end

  def embeds_for(matches)
    matches.filter_map do |id|
      user = @booru.users.show(id)
      user.embed if user.succeeded?
    end
  end
end
