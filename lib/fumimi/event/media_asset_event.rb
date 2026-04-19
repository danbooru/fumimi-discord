require "fumimi/event"

class Fumimi::Event::MediaAssetEvent < Fumimi::Event
  def self.pattern
    /asset #([0-9]+)/i
  end

  # def self.model_for_link_capture
  #   "media_assets"
  # end

  # def self.delete_link_embed?
  #   true
  # end

  def embeds_for(matches)
    media_assets = @booru.media_assets.index("search[id]": matches.join(","))
    media_assets.map { |asset| asset.embed(nsfw_channel: true) }
    # TODO: maybe use AI tags to decide whether to show an embed
  end
end
