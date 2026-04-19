require "fumimi/event"

class Fumimi::Event::PullEvent < Fumimi::Event
  def self.pattern
    /pull #([0-9]+)/i
  end

  def messages_for(matches)
    matches.map { |id| "https://github.com/danbooru/danbooru/pull/#{id}" }
  end
end
