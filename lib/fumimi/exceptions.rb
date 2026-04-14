module Fumimi::Exceptions
  class FumimiException < StandardError
    def embed_title
      "Exception Encountered!"
    end

    def embed_description
      # Automatically populated from the message, if not present
    end

    def embed_image
      "https://i.imgur.com/0CsFWP3.png"
    end
  end

  class NoResultsError < FumimiException
    def embed_title
      "No results found."
    end

    def embed_description
      "Fumimi tried really hard, but there were no results..."
    end
  end

  class CommandArgumentError < FumimiException
    def embed_title
      "Bad argument!"
    end
  end

  class PermissionError < FumimiException
    def embed_title
      "No Permissions"
    end

    def embed_description
      "You can't do that! Stop touching me that way!"
    end

    def embed_image
      "https://imgur.com/fZ4Hr2g.jpg"
    end
  end

  class MissingCredentialsError < FumimiException
  end
end
