DEBUG = %w[1 true yes].include?(ENV["DEBUG"]&.downcase)

if DEBUG
  require "byebug"
  require "pry"
end
