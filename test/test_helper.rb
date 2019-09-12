# frozen_string_literal: true

require "minitest/autorun"
require "minitest/pride"
require "mocha/minitest"
require "activerecord-mysql2rgeo-adapter"
require "erb"
require "simplecov"
SimpleCov.start

begin
  require "byebug"
rescue LoadError
  # ignore
end

module ActiveRecord
  class Base
    DATABASE_CONFIG_PATH = File.dirname(__FILE__) << "/database.yml"
    DATABASE_LOCAL_CONFIG_PATH = File.dirname(__FILE__) << "/database_local.yml"

    def self.test_connection_hash
      db_config_path = File.exist?(DATABASE_LOCAL_CONFIG_PATH) ? DATABASE_LOCAL_CONFIG_PATH : DATABASE_CONFIG_PATH
      YAML.safe_load(ERB.new(File.read(db_config_path)).result)
    end

    def self.establish_test_connection
      establish_connection test_connection_hash
    end
  end
end

class SpatialModel < ActiveRecord::Base
  establish_test_connection
end

class SpatialMultiModel < ActiveRecord::Base
  establish_test_connection
end

module ActiveSupport
  class TestCase
    self.test_order = :sorted

    def factory
      RGeo::Cartesian.preferred_factory(srid: 0)
    end

    def geographic_factory
      RGeo::Geographic.spherical_factory(srid: 4326)
    end

    def spatial_factory_store
      RGeo::ActiveRecord::SpatialFactoryStore.instance
    end
  end
end
