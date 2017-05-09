require "danbooru/model"
require "danbooru/has_dtext_fields"

class Danbooru
  class ForumPost < Danbooru::Model
    include Danbooru::HasDTextFields
  end
end
