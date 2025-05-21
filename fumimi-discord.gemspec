lib = File.expand_path("lib", __dir__)
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
  spec.metadata["rubygems_mfa_required"] = "true"
end
