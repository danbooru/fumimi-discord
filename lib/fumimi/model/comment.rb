require "fumimi/model"

class Fumimi::Model::Comment < Fumimi::Model
  delegate :embed_thumbnail, :embed_is_nsfw?, to: :post

  def embed_author
    { name: creator.at_name, url: creator.url }
  end

  def embed_description
    Fumimi::DText.dtext_to_markdown(body)
  end

  def embed_footer
    "Score: #{score}"
  end
end
