require "fumimi/model"

class Fumimi::Model::User < Danbooru::Model
  def at_name
    "@#{name}"
  end
end
