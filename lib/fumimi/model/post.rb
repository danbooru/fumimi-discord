require "fumimi/model"

class Fumimi::Model::Post < Fumimi::Model
  CENSORED_TAGS = ENV["FUMIMI_CENSORED_TAGS"].to_s.split

  delegate :image_width, :image_height, :file_ext, :file_size, to: :media_asset

  def embed_color
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

  def embed_image
    return nil if censored?
    return file_variant.url if file_ext.match?(/jpe?g|png|gif/i)

    preview_variant.url
  end

  def embed_thumbnail
    return nil if censored?

    preview_variant.url
  end

  def embed_is_nsfw?
    rating != "g"
  end

  def embed_footer
    post_info = "#{score}⇧ #{fav_count}♥ | Rating: #{rating.upcase}"
    file_info = "#{image_width}x#{image_height} (#{file_size.to_fs(:human_size, precision: 4)} #{file_ext})"

    "#{post_info} | #{file_info}"
  end

  def censored?
    tags.grep(/^(#{CENSORED_TAGS.join("|")})$/).any?
  end

  def source_url
    # TODO: maybe add icons for pixiv etc. Would need deep danbooru integration
    Addressable::URI.heuristic_parse(source) rescue nil
  end

  def tags
    tag_string.split
  end

  def file_variant
    media_asset.variants.detect { |v| v["type"] == "original" }
  end

  def preview_variant
    media_asset.variants.detect { |v| v["type"] == "360x360" }
  end
end
