require "danbooru/tag"

class Fumimi
  class Tag < Danbooru::Tag
    def example_post
      case category
      when 1 # artist
        search = "#{name} rating:safe order:score filetype:jpg limit:1 status:any"
      when 3 # copy
        search = "#{name} everyone rating:safe order:score filetype:jpg limit:1 status:any"
      when 4 # char
        search = "#{name} chartags:1 rating:safe order:score filetype:jpg limit:1 status:any"
      else # meta or general
        search = "#{name} rating:safe order:score filetype:jpg limit:1 status:any"
      end

      post = booru.posts.index(tags: search).first
      post
    end
  end
end
