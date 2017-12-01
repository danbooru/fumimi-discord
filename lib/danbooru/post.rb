require "danbooru/model"

class Danbooru
  class Post < Danbooru::Model
    def absolute_preview_file_url
      "#{booru.host}#{preview_file_url}"
    end
  end
end
