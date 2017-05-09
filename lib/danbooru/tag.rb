require "danbooru/model"

class Danbooru
  class Tag < Danbooru::Model
    def example_post(booru)
      case category
      when 0
        search = "#{name} rating:safe order:score filetype:jpg limit:1"
      when 1 # artist
        search = "#{name} rating:safe order:score filetype:jpg limit:1"
      when 3 # copy
        search = "#{name} everyone rating:safe order:score filetype:jpg limit:1"
      when 4 # char
        search = "#{name} chartags:1 rating:safe order:score filetype:jpg limit:1"
      end

      post = booru.posts.index(tags: search).first
      post
    end
  end
end
