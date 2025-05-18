lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

Gem::Specification.new do |spec|
  spec.name          = "fumimi-discord"
  spec.version       = "0.1.0"
  spec.authors       = ["evazion"]
  spec.email         = ["noizave@gmail.com"]

  spec.summary       = "A Danbooru Discord bot."
  spec.homepage      = "https://github.com/evazion/fumimi-discord.git"
  spec.license       = "MIT"

  spec.files         = []
  spec.files        += Dir["lib/**"]
  spec.files        += Dir["test/**"]
  spec.files        += Dir["bin/**"]
  spec.bindir        = "bin"
  spec.executables   = %w[fumimi]
  spec.require_paths = ["lib"]

  spec.required_ruby_version = "~> 3.4"

  #spec.add_runtime_dependency "activesupport", "~> 6"
  #spec.add_runtime_dependency "dotenv", "~> 2"
  #spec.add_runtime_dependency "addressable", "~> 2"
  #spec.add_runtime_dependency "google-cloud-bigquery"
  #spec.add_runtime_dependency "google-cloud-storage"
  #spec.add_runtime_dependency "terminal-table", "~> 1.7"
  #spec.add_runtime_dependency "gli", "~> 2.16"
  #spec.add_runtime_dependency "dtext_rb", "~> 1"
  #spec.add_runtime_dependency "dentaku"
  #spec.add_runtime_dependency "ruby-booru", "~> 0.2"

  spec.add_development_dependency "bundler", "~> 2"
  spec.add_development_dependency "rake", "~> 13.0"
  spec.add_development_dependency "pry", "~> 0.10"
  spec.add_development_dependency "pry-byebug", "~> 3.4"
  spec.add_development_dependency "minitest", "~> 5.0"
end
