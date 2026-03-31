# frozen_string_literal: true

require "bundler/setup"
Bundler.require :development
require "minitest/autorun"
require "minitest/pride"
require "minitest/excludes"

require "erb"
require "byebug" if ENV["BYEBUG"]
require "activerecord-mysql2rgeo-adapter"

TRIAGE_MSG = "Needs triage and fixes. See #378"
TEST_GEOMETRIC_SRID = 3857

module ActiveRecord
  module Type
    class TypeMap
      DEFAULT_SPATIAL_TYPE_KEYS = %w[
        geography
        geometry
        geometry_collection
        line_string
        multi_line_string
        multi_point
        multi_polygon
        st_point
        st_polygon
      ].freeze

      TYPE_KEY_ALIASES = {
        "geometrycollection" => "geometry_collection",
        "linestring" => "line_string",
        "multilinestring" => "multi_line_string",
        "multipoint" => "multi_point",
        "multipolygon" => "multi_polygon",
        "point" => "st_point",
        "polygon" => "st_polygon",
      }.freeze

      def keys
        keys = raw_keys
        spatial_keys = DEFAULT_SPATIAL_TYPE_KEYS.select { |key| keys.include?(key) }
        spatial_keys + (keys - spatial_keys)
      end

      private

      def raw_keys
        keys = @parent ? @parent.send(:raw_keys) : []
        keys.concat(@mapping.keys.map(&:to_s))
        keys.map! { |key| TYPE_KEY_ALIASES.fetch(key, key) }
        keys.uniq
      end
    end
  end
end

if ENV["ARCONN"]
  # only install activerecord schema if we need it
  require "cases/helper"

  def load_mysql_specific_schema
    original_stdout = $stdout
    $stdout = StringIO.new

    load "schema/mysql_specific_schema.rb"

    ActiveRecord::FixtureSet.reset_cache
  ensure
    $stdout = original_stdout
  end

  load_mysql_specific_schema
else
  module ActiveRecord
    class Base
      DATABASE_CONFIG_PATH = "#{__dir__}/database.yml".freeze

      def self.test_connection_hash
        conns = YAML.safe_load(ERB.new(File.read(DATABASE_CONFIG_PATH)).result)
        conn_hash = conns["connections"]["mysql2rgeo"]["arunit"]
        conn_hash.merge(adapter: "mysql2rgeo", prepared_statements: false)
      end

      def self.establish_test_connection
        establish_connection test_connection_hash
      end
    end
  end

  ActiveRecord::Base.establish_test_connection

end

ActiveRecord::SchemaDumper.ignore_tables = %w[
  layer
  raster_columns
  raster_overviews
  spatial_ref_sys
  topology
]

class SpatialModel < ActiveRecord::Base
end

require "timeout"

module TestTimeoutHelper
  def time_it(&block)
    t0 = Minitest.clock_time

    timeout = ENV.fetch("TEST_TIMEOUT", 10).to_i
    Timeout.timeout(timeout, Timeout::Error, "Test took over #{timeout} seconds to finish", &block)
  ensure
    self.time = Minitest.clock_time - t0
  end
end

module ActiveSupport
  class TestCase
    include TestTimeoutHelper

    self.test_order = :sorted

    def database_version
      @database_version ||= SpatialModel.connection.select_value("SELECT version()")
    end

    def factory(srid: TEST_GEOMETRIC_SRID)
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
