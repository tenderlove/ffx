require "rake/testtask"

Rake::TestTask.new(:test) do |t|
  t.libs << "test"
  t.libs << "."
  t.test_files = FileList["test/**/test_*.rb"]
  t.warning = false
end

task default: :test
