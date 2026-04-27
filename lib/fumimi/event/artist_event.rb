class Fumimi::Event::ArtistEvent < Fumimi::Event
  def self.pattern
    /artist #([0-9]+)/i
  end

  def messages_for(matches)
    matches.map { |artist| "https://danbooru.donmai.us/artists/#{artist}" }
  end
end
