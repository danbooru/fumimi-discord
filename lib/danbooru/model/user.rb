require "danbooru/model"

class Danbooru::Model::User < Danbooru::Model
  def at_name
    "@#{name}"
  end
end
