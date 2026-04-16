class Fumimi::Model::MediaAsset < Fumimi::Model
  def embed_footer
    file_info
  end

  def shortlink
    "asset ##{id}"
  end

  def file_info
    "#{image_width}x#{image_height} (#{file_size.to_fs(:human_size, precision: 4)} #{file_ext})"
  end

  def file_variant
    variants.detect { |v| v["type"] == "original" }
  end

  def preview_variant
    variants.detect { |v| v["type"] == "360x360" }
  end
end
