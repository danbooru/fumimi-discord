require "fumimi/model"

class Fumimi::Model::Comment < Fumimi::Model
  include Fumimi::HasDTextFields

  delegate :embed_thumbnail, :embed_is_nsfw?, to: :post

  def embed_author
    { name: creator.at_name, url: creator.url }
  end

  def embed_description
    pretty_body
  end

  def embed_footer
    "Score: #{score}"
  end
end
