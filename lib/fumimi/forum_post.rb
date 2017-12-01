require "danbooru/forum_post"
require "fumimi/model"

class Fumimi
  class ForumPost < Danbooru::ForumPost
    include Fumimi::Model
  end
end
