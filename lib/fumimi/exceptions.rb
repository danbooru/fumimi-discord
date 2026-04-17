module Fumimi::Exceptions
  class FumimiException < StandardError
    def embed_title
      "Exception Encountered!"
    end

    def embed_description
      msg = message.presence
      # message falls back to class name when none was passed, so exclude that
      return msg if msg && msg != self.class.name

      default_description
    end

    def embed_image
      "https://i.imgur.com/0CsFWP3.png"
    end

    def default_description
      # overwritten by subclasses
    end
  end

  class NoResultsError < FumimiException
    def embed_title
      "No Results."
    end

    def embed_image
      "https://cdn.donmai.us/original/4d/5d/4d5dc247841712306a142267eb07cb0a.jpg"
    end

    def default_description
      "Fumimi tried really hard, but there were no results..."
    end
  end

  class CommandArgumentError < FumimiException
    def embed_title
      "Bad Argument!"
    end
  end

  class PermissionError < FumimiException
    def embed_title
      "No Permissions"
    end

    def embed_image
      "https://imgur.com/fZ4Hr2g.jpg"
    end

    def default_description
      "You can't do that! Stop touching me that way!"
    end
  end

  class MissingCredentialsError < FumimiException
  end
end
