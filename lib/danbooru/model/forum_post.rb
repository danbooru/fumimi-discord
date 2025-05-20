require "danbooru/model"
require "danbooru/has_dtext_fields"

class Danbooru::Model::ForumPost < Danbooru::Model
  include Danbooru::HasDTextFields
end
