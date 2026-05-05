class Fumimi::MessageEvent::PixivEvent < Fumimi::MessageEvent
  def self.pattern
    /pixiv #([0-9]+)/i
  end

  def messages_for(matches)
    matches.map { |id| "https://www.pixiv.net/artworks/#{id}" }
  end
end
