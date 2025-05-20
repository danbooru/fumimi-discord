require "danbooru/model"

class Danbooru::Model::Post < Danbooru::Model
  def source_url
    Addressable::URI.heuristic_parse(source) rescue nil
  end

  def tags
    tag_string.split
  end
end
