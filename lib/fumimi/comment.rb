require "danbooru/comment"
require "fumimi/model"

class Fumimi
  class Comment < Danbooru::Comment
    include Fumimi::Model
  end
end
