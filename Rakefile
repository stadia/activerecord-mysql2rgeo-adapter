require "bundler/gem_tasks"
require "rake/testtask"

task default: :test

Rake::TestTask.new(:test) do |t|
  t.libs << "lib"
  t.libs << "test"
  t.test_files = Dir["test/tc_*.rb"].sort
  t.verbose = false
end
