source "https://rubygems.org"

gem "activesupport", require: "active_support/all"
gem "addressable", require: "addressable/uri"
gem "date"
gem "dentaku"
# waiting for this to be released as a new version: https://github.com/shardlab/discordrb/issues/311
gem "discordrb", github: "shardlab/discordrb", ref: "97c2856fabea08d9392248aef3d7e8cf12aa8556"
gem "dotenv"
gem "dtext_rb", github: "danbooru/danbooru", glob: "lib/dtext_rb/dtext_rb.gemspec",
                ref: "cb4061ef17b284451734e10409f57e6b552b699a", require: "dtext"
gem "faraday"
gem "faraday-follow_redirects", require: "faraday/follow_redirects"
gem "faraday-net_http_persistent", require: "faraday/net_http_persistent"
gem "faraday-retry", require: "faraday/retry"
gem "json"
gem "logger"
gem "nokogiri"
gem "optparse"
gem "ostruct"
gem "prophet-rb"
gem "rack"
gem "rackup", require: "rackup/handler/webrick"
gem "time"
gem "unicode-display_width", require: "unicode/display_width/string_ext"
gem "webrick"
gem "zeitwerk"

group :development, :test do
  gem "debug"
  gem "listen" # For ActiveSupport::EventedFileUpdateChecker
  gem "pry"
  gem "rake", require: false
  gem "rubocop", require: false
end

group :test do
  gem "minitest"
  gem "minitest-mock"
end
