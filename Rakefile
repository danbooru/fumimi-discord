require "bundler/gem_tasks"
require "rake/testtask"

Rake::TestTask.new(:test) do |t|
  t.libs << "test"
  t.libs << "lib"
  t.test_files = FileList['test/**/*_test.rb']
end

task :default => :test

$date = Time.now.beginning_of_hour.utc.iso8602.to_s
$bucket = "evazion"
$resources = %i[
  pools
]

namespace :export do
  desc "Export everything to gs://#{$bucket}/danbooru/#{$date}/"
  task :all => $resources

  $resources.each do |name|
    url = "gs://#{bucket}/danbooru/#{$date}/#{name}.json.gz"

    desc "Export /#{name}.json to #{url}"
    task name do |t|
      bash "bin/booru #{name} export | tail -n +1 | gzip -3 | gsutil cp - #{url}"
      bash "gsutil acl ch -u AllUsers:R #{url}"
    end
  end
end
