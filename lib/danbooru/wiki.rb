require "danbooru/model"
require "danbooru/has_dtext_fields"

class Danbooru
  class Wiki < Danbooru::Model
    include Danbooru::HasDTextFields
  end
end
