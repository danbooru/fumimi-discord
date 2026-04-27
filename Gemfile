source "https://rubygems.org"

gem "activesupport"
gem "addressable"
gem "dentaku"
# waiting for this to be released as a new version: https://github.com/shardlab/discordrb/issues/311
gem "discordrb", github: "shardlab/discordrb", require: false, ref: "97c2856fabea08d9392248aef3d7e8cf12aa8556"
gem "dotenv"
gem "dtext_rb", github: "danbooru/danbooru", glob: "lib/dtext_rb/dtext_rb.gemspec",
                ref: "cb4061ef17b284451734e10409f57e6b552b699a"
gem "http"
gem "json"
gem "nokogiri"
gem "ostruct"
gem "prophet-rb"
gem "rack"
gem "rackup"
gem "retriable"
gem "webrick"

group :development, :test do
  gem "debug"
  gem "pry"
  gem "rake"
  gem "rubocop"
end

group :test do
  gem "minitest"
  gem "minitest-mock"
end
