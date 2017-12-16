lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

require 'fumimi/version'

Gem::Specification.new do |spec|
  spec.name          = "fumimi-discord"
  spec.version       = Fumimi::VERSION
  spec.authors       = ["evazion"]
  spec.email         = ["noizave@gmail.com"]

  spec.summary       = "A Danbooru Discord bot."
  spec.homepage      = "https://github.com/evazion/fumimi-discord.git"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end
  spec.bindir        = "bin"
  spec.executables   = %w[fumimi]
  spec.require_paths = ["lib"]

  spec.required_ruby_version = '~> 2.4'

  spec.add_runtime_dependency "activesupport", "~> 5"
  spec.add_runtime_dependency "dotenv", "~> 2"
  spec.add_runtime_dependency "addressable", "~> 2.5"
  spec.add_runtime_dependency "google-cloud-bigquery", "~> 0.26"
  spec.add_runtime_dependency "google-cloud-storage", "~> 1.0"
  spec.add_runtime_dependency "terminal-table", "~> 1.7"
  spec.add_runtime_dependency "pg", "~> 0.20"
  spec.add_runtime_dependency "gli", "~> 2.16"
  spec.add_runtime_dependency "sequel", "~> 5.2"
  spec.add_runtime_dependency "sqlite3", "~> 1.3"
  spec.add_runtime_dependency "bitly", "~> 1.1"
  spec.add_runtime_dependency "dtext_rb", "~> 1.6"
  spec.add_runtime_dependency "dentaku"
  spec.add_runtime_dependency "ruby-booru", "~> 0.2"

  spec.add_development_dependency "bundler", "~> 1.14"
  spec.add_development_dependency "rake", "~> 12.0"
  spec.add_development_dependency "pry", "~> 0.10"
  spec.add_development_dependency "pry-byebug", "~> 3.4"
  spec.add_development_dependency "minitest", "~> 5.0"
end
