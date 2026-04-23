lib = File.expand_path("lib", __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

Gem::Specification.new do |spec|
  spec.name          = "fumimi-discord"
  spec.version       = "1.0.0"
  spec.authors       = %w[evazion nonamethanks]
  spec.email         = ["noizave@gmail.com", "hellafrickingepic@gmail.com"]

  spec.summary       = "A Danbooru Discord bot."
  spec.homepage      = "https://github.com/danbooru/fumimi-discord.git"
  spec.license       = "MIT"

  spec.files         = []
  spec.files        += Dir["lib/**"]
  spec.files        += Dir["test/**"]
  spec.files        += Dir["bin/**"]
  spec.bindir        = "bin"
  spec.executables   = %w[fumimi]
  spec.require_paths = ["lib"]

  spec.required_ruby_version = "4.0.3"
  spec.metadata["rubygems_mfa_required"] = "true"
end
