require "danbooru/model"

class Danbooru::Model::IqdbQuery < Danbooru::Model
  def initialize(api, attributes)
    super
    self.post = Danbooru::Model::Post.new(api, self.post)
  end
end
