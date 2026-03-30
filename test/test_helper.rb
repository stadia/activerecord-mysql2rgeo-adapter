# frozen_string_literal: true

require "bundler/setup"
require "minitest/autorun"
require "minitest/pride"
require "mocha/minitest"
require "activerecord-mysql2rgeo-adapter"
require "erb"

require "byebug" if ENV["BYEBUG"]

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

ActiveRecord::Base.establish_test_connection

class SpatialModel < ActiveRecord::Base
end

class SpatialMultiModel < ActiveRecord::Base
end

module ActiveSupport
  class TestCase
    self.test_order = :sorted

    def database_version
      @database_version ||= SpatialModel.connection.select_value("SELECT version()")
    end

    def factory(srid: 3857)
      RGeo::Cartesian.preferred_factory(srid: srid)
    end

    def geographic_factory
      RGeo::Geographic.spherical_factory(srid: 4326)
    end

    def spatial_factory_store
      RGeo::ActiveRecord::SpatialFactoryStore.instance
    end

    def reset_spatial_store
      spatial_factory_store.clear
      spatial_factory_store.default = nil
    end
  end
end
