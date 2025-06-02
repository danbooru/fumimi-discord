require "fumimi/model"

class Fumimi::Model::Post < Fumimi::Model
  NSFW_BLUR = ENV["FUMIMI_NSFW_BLUR"] || 50
  CENSORED_TAGS = ENV["FUMIMI_CENSORED_TAGS"].to_s.split

  delegate :image_width, :image_height, :file_ext, :file_size, to: :media_asset

  def source_url
    Addressable::URI.heuristic_parse(source) rescue nil
  end

  def tags
    tag_string.split
  end

  def embed(embed, channel)
    embed.title = shortlink
    embed.url = url
    embed.image = embed_image(channel.nsfw?)
    embed.color = border_color
    embed.footer = embed_footer

    embed
  end

  def embed_image_url
    if file_ext.match?(/jpe?g|png|gif/i)
      file_variant.url
    else
      preview_variant.url
    end
  end

  def file_variant
    media_asset.variants.detect { |v| v["type"] == "original" }
  end

  def preview_variant
    media_asset.variants.detect { |v| v["type"] == "360x360" }
  end

  def embed_thumbnail(nsfw_channel)
    Discordrb::Webhooks::EmbedThumbnail.new(url: preview_variant.url.to_s) unless censored? || unsafe?(nsfw_channel)
  end

  def embed_image(nsfw_channel)
    Discordrb::Webhooks::EmbedImage.new(url: embed_image_url.to_s) unless censored? || unsafe?(nsfw_channel)
  end

  def unsafe?(nsfw_channel)
    rating != "g" && !nsfw_channel
  end

  def censored?
    tags.grep(/^(#{CENSORED_TAGS.join("|")})$/).any?
  end

  def border_color
    if is_flagged
      Fumimi::Colors::RED
    elsif parent_id
      Fumimi::Colors::YELLOW
    elsif has_active_children
      Fumimi::Colors::GREEN
    elsif is_pending
      Fumimi::Colors::BLUE
    elsif is_deleted
      Fumimi::Colors::WHITE
    end
  end

  def embed_footer
    post_info = "#{score}⇧ #{fav_count}♥ | Rating: #{rating.upcase}"
    file_info = "#{image_width}x#{image_height} (#{file_size.to_fs(:human_size, precision: 4)} #{file_ext})"
    timestamp = "#{created_at.strftime("%F")}"

    Discordrb::Webhooks::EmbedFooter.new(
      text: "#{post_info} | #{file_info} | #{timestamp}"
    )
  end
end
