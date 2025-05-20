require "danbooru/model"
require "danbooru/has_dtext_fields"

class Danbooru::Model::Comment < Danbooru::Model
  include Danbooru::HasDTextFields
end
