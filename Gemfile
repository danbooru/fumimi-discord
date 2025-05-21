source "https://rubygems.org"

gemspec

gem "activesupport", "~> 8.0"
gem "addressable", "~> 2.8"
gem "connection_pool", "~> 2.5"
gem "dentaku", "~> 3.5"
gem "discordrb", github: "shardlab/discordrb", require: false, ref: "402bebe1d075796f5fdee1223fc883e24756b6e0"
gem "dotenv", "~> 3.1"
gem "dtext_rb", "~> 1.13", github: "danbooru/danbooru", glob: "lib/dtext_rb/dtext_rb.gemspec",
                           ref: "cb4061ef17b284451734e10409f57e6b552b699a"
gem "http", "~> 4.4"
gem "nokogiri", "~> 1.18"
gem "retriable", "~> 3.1"

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
