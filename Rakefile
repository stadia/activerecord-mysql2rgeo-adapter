require "bundler/gem_tasks"
require "rake/testtask"

task default: :test

Rake::TestTask.new(:test) do |t|
  t.libs << "lib"
  t.libs << "test"
  t.test_files = Dir["test/cases/**/*_test.rb"].sort + ["test/tasks_test.rb"]
  t.verbose = false
end
