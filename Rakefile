require "bundler/gem_tasks"
require "rake/testtask"
require_relative "test/rake_helper"

task default: [:test]
task test: "test:mysql2rgeo"

Rake::TestTask.new(:test_mysql2rgeo) do |t|
  t.libs << mysql2rgeo_test_load_paths
  t.test_files = mysql2rgeo_test_files
  t.verbose = false
end

Rake::TestTask.new(:test_activerecord) do |t|
  t.libs << mysql2rgeo_test_load_paths
  t.test_files = activerecord_test_files
  t.verbose = false
end

Rake::TestTask.new(:test_all) do |t|
  t.libs << mysql2rgeo_test_load_paths
  t.test_files = all_test_files
  t.verbose = false
end

# We invoke the tests from here so we can add environment varaible(s)
# necessary for ActiveRecord tests. TestTask.new runs its block
# regardless of whether it has been invoked or not, so environment
# variables cannot be set in there if they're only needed for specific
# tests.
namespace :test do
  task :mysql2rgeo do
    Rake::Task["test_mysql2rgeo"].invoke
  end

  task :activerecord do
    ENV["ARCONN"] = "mysql2rgeo"
    Rake::Task["test_activerecord"].invoke
  end

  task :all do
    ENV["ARCONN"] = "mysql2rgeo"
    Rake::Task["test_all"].invoke
  end
end
