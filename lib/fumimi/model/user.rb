require "fumimi/model"

class Fumimi::Model::User < Fumimi::Model
  def at_name
    "@#{name}"
  end
end
