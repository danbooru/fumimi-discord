require "danbooru/model"

class Danbooru::Model::IqdbQuery < Danbooru::Model
  def cast_attribute(name, value)
    return Danbooru::Model::Post.new(api, value) if name == "post"
    super
  end
end
