# frozen_string_literal: true

require "./lib/active_record/connection_adapters/mysql2rgeo/version.rb"

Gem::Specification.new do |spec|
  spec.name = "activerecord-mysql2rgeo-adapter"
  spec.summary = "ActiveRecord adapter for MySQL, based on RGeo."
  spec.description =
    "ActiveRecord connection adapter for MySQL. It is based on the stock MySQL adapter, and adds " \
    "built-in support for the spatial extensions provided by MySQL. It uses the RGeo library to represent " \
    "spatial data in Ruby."

  spec.version = ActiveRecord::ConnectionAdapters::Mysql2Rgeo::VERSION
  spec.author = "Yongdae Hwang"
  spec.email = "stadia@gmail.com"
  spec.homepage = "http://github.com/stadia/activerecord-mysql2rgeo-adapter"
  spec.license = "BSD-3-Clause"

  spec.files = Dir["lib/**/*", "LICENSE.txt"]
  spec.platform = Gem::Platform::RUBY

  spec.required_ruby_version = ">= 2.5.0"

  spec.add_dependency "activerecord", "~> 6.0.0"
  spec.add_dependency "rgeo-activerecord", "~> 6.0"

  spec.add_development_dependency "rake", "~> 13.0"
  spec.add_development_dependency "minitest", "~> 5.4"
  spec.add_development_dependency "mocha", "~> 1.1"
  spec.add_development_dependency "appraisal", "~> 2.0"
end
