class Fumimi::MessageEvent::ArtistEvent < Fumimi::MessageEvent
  def self.pattern
    /artist #([0-9]+)/i
  end

  def messages_for(matches)
    matches.map { |artist| "#{@booru.url}/artists/#{artist}" }
  end
end
