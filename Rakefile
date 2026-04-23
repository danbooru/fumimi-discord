require "rake/testtask"

selected_test_files = ARGV.grep(%r{\Atest/.+_test\.rb\z})

desc "Run tests"
Rake::TestTask.new(:test) do |t|
  t.libs << "lib"
  t.libs << "test"

  if selected_test_files.empty?
    t.pattern = "test/**/*_test.rb"
  else
    t.test_files = selected_test_files
  end

  t.warning = false
end
