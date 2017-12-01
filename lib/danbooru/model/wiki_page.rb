require "danbooru/model"
require "danbooru/has_dtext_fields"

class Danbooru::Model::WikiPage < Danbooru::Model
  include Danbooru::HasDTextFields
end
