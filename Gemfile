source "https://rubygems.org"

gemspec

gem "activesupport"
gem "addressable"
gem "connection_pool"
gem "dentaku"
gem "discordrb", github: "shardlab/discordrb", require: false, ref: "557caa06b2cdd69e53f278d135a264543490158b"
gem "dotenv"
gem "dtext_rb", github: "danbooru/danbooru", glob: "lib/dtext_rb/dtext_rb.gemspec",
                ref: "cb4061ef17b284451734e10409f57e6b552b699a"
gem "http"
gem "nokogiri"
gem "ostruct"
gem "rdoc"
gem "retriable"

group :development do
  gem "bundler", "~> 2.6"
  gem "pry", "~> 0.15.2"
  gem "pry-byebug", "~> 3.11"
  gem "rake", "~> 13.2"
  gem "rubocop", "~> 1.75"
end

group :test do
  gem "minitest", "~> 5.25"
end

gem "unicode-display_width", "~> 3.1"
