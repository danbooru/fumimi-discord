require "danbooru/model"
require "danbooru/has_dtext_fields"

class Danbooru
  class Comment < Danbooru::Model
    include HasDTextFields
  end
end
