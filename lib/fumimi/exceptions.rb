module Fumimi::Exceptions
  class CommandArgumentError < StandardError; end
  class PermissionError < StandardError; end
  class MissingCredentialsError < StandardError; end
end
