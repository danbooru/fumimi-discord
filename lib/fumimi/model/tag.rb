require "danbooru/model/tag"
require "fumimi/model"

class Fumimi::Model::Tag < Danbooru::Model::Tag
  include Fumimi::Model

  def example_post
    case category
    when 1 # artist
      search = "#{name} rating:general order:score filetype:jpg limit:1 status:any"
    when 3 # copy
      search = "#{name} everyone rating:general order:score filetype:jpg limit:1 status:any copytags:<5 -parody -crossover"
    when 4 # char
      search = "#{name} solo chartags:<5 rating:general order:score filetype:jpg limit:1 status:any"
    else # meta or general
      search = "#{name} rating:general -animated -6+girls -comic order:score limit:1 status:any"
    end

    response = booru.posts.index(tags: search)
    response.first unless response.failed?
  end
end
