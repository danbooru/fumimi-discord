module Danbooru::Exceptions
  class DanbooruError < StandardError
    def embed_title
      "Exception Encountered!"
    end

    def embed_description
    end

    def embed_image
      "https://i.imgur.com/0CsFWP3.png"
    end
  end

  class BadRequestError < DanbooruError
    def embed_description
      "Bad parameters."
    end
  end

  class TemporaryError < DanbooruError
  end

  class TimeoutError < DanbooruError
    def embed_title
      "Timeout Encontered!"
    end

    def embed_description
      "The query went into timeout..."
    end
  end

  class DownbooruError < DanbooruError
    def embed_title
      "Downbooru"
    end

    def embed_description
      "The site is down!"
    end

    def embed_image
      "https://i.imgur.com/DHMBEGZ.png"
    end
  end

  class MaintenanceError < DownbooruError
    def embed_description
      "The site is down for maintenance!"
    end
  end
end
