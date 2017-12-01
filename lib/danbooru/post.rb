require "danbooru/model"

class Danbooru
  class Post < Danbooru::Model
    def url
      "#{booru.host}/#{id}"
    end

    def shortlink
      "post ##{id}"
    end

    def absolute_preview_file_url
      "#{booru.host}/#{preview_file_url}"
    end
  end
end
