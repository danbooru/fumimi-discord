require "danbooru/model"

class Danbooru
  class User < Danbooru::Model
    def url
      "#{booru.host}/users?name=#{CGI::escape(name)}"
    end

    def at_name
      "@#{name}"
    end
  end
end
