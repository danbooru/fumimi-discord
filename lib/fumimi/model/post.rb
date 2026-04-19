require "fumimi/model"

class Fumimi::Model::Post < Fumimi::Model
  CENSORED_TAGS = ENV["FUMIMI_CENSORED_TAGS"].to_s.split

  delegate :file_ext, :file_info, :file_variant, :preview_variant, to: :media_asset

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
    return nil unless nsfw_channel? || !nsfw?

    return file_variant&.url if file_ext.match?(/jpe?g|png|gif/i)

    preview_variant&.url
  end

  def embed_thumbnail
    return nil if censored?
    return nil unless nsfw_channel? || !nsfw?

    preview_variant&.url
  end

  def nsfw?
    rating != "g"
  end

  def censored?
    tags.grep(/^(#{CENSORED_TAGS.join("|")})$/).any?
  end

  def embed_footer
    post_info = "#{score}⇧ #{fav_count}♥"
    rating_info = "Rating: #{rating.upcase}"

    [post_info, rating_info, file_info].join("  •  ")
  end

  def source_url
    # TODO: maybe add icons for pixiv etc. Would need deep danbooru integration
    Addressable::URI.heuristic_parse(source) rescue nil
  end

  def tags
    tag_string.split
  end
end
