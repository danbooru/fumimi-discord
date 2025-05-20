require "danbooru/model"

class Danbooru::Model::Post < Danbooru::Model
  def fav_ids
    fav_string.split.grep(/([0-9]+)/) { $1.to_i }
  end

  def pool_ids
    pool_string.split.grep(/([0-9]+)/) { $1.to_i }
  end

  def source_url
    Addressable::URI.heuristic_parse(source) rescue nil
  end

  def tags
    tag_string.split
  end
end
