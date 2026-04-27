class Fumimi::Event::IssueEvent < Fumimi::Event
  def self.pattern
    /issue #([0-9]+)/i
  end

  def messages_for(matches)
    matches.map { |id| "https://github.com/danbooru/danbooru/issues/#{id}" }
  end
end
