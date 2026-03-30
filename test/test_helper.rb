# frozen_string_literal: true

require "bundler/setup"
Bundler.require :development
require "minitest/autorun"
require "minitest/pride"
require "minitest/excludes"
MiniTest = Minitest unless defined?(MiniTest)
require "mocha/minitest"
require "erb"
require "byebug" if ENV["BYEBUG"]
require "activerecord-mysql2rgeo-adapter"

TRIAGE_MSG = "Needs triage and fixes. See #378"

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
        "polygon" => "st_polygon"
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

module ActiveRecord
  module ConnectionAdapters
    module Mysql2Rgeo
      VERSION = ActiveRecord::ConnectionAdapters::Mysql2Rgeo::VERSION unless const_defined?(:VERSION)
    end
  end
end

module ActiveRecord
  class PredicateBuilder
    class BasicObjectHandler
      unless method_defined?(:mysql2rgeo_call_without_spatial)
        alias_method :mysql2rgeo_call_without_spatial, :call

        def call(attribute, value)
          if spatial_attribute?(attribute) && spatial_query_value?(value)
            attribute.st_equals(Arel.spatial(value))
          else
            mysql2rgeo_call_without_spatial(attribute, value)
          end
        end

        private

        def spatial_attribute?(attribute)
          relation = attribute.respond_to?(:relation) ? attribute.relation : nil
          relation.respond_to?(:engine) &&
            relation.engine.type_for_attribute(attribute.name.to_s).respond_to?(:spatial?) &&
            relation.engine.type_for_attribute(attribute.name.to_s).spatial?
        rescue StandardError
          false
        end

        def spatial_query_value?(value)
          RGeo::Feature::Instance === value || spatial_wkt?(value)
        end

        def spatial_wkt?(value)
          value.is_a?(String) &&
            value.match?(/\A(?:SRID=\d+;)?\s*(?:point|linestring|polygon|multipoint|multilinestring|multipolygon|geometrycollection)\b/i)
        end
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
      DATABASE_CONFIG_PATH = File.dirname(__FILE__) << "/database.yml"

      def self.test_connection_hash
        conns = YAML.load(ERB.new(File.read(DATABASE_CONFIG_PATH)).result)
        conn_hash = conns["connections"]["mysql2rgeo"]["arunit"]
        conn_hash.merge(adapter: "mysql2rgeo", prepared_statements: false)
      end

      def self.establish_test_connection
        establish_connection test_connection_hash
      end
    end
  end

  ActiveRecord::Base.establish_test_connection

  conn = ActiveRecord::Base.connection
  %w[geometry_columns geography_columns].each do |view_name|
    conn.execute("DROP VIEW IF EXISTS #{conn.quote_table_name(view_name)}")
  end
  conn.execute <<~SQL
    CREATE SPATIAL REFERENCE SYSTEM IF NOT EXISTS 3785
    NAME 'WGS 84 / Popular Visualisation Sphere'
    ORGANIZATION 'EPSG' IDENTIFIED BY 3785
    DEFINITION 'PROJCS["WGS 84 / Popular Visualisation Sphere",GEOGCS["WGS 84",DATUM["World Geodetic System 1984",SPHEROID["WGS 84",6378137,298.257223563,AUTHORITY["EPSG","7030"]],AUTHORITY["EPSG","6326"]],PRIMEM["Greenwich",0,AUTHORITY["EPSG","8901"]],UNIT["degree",0.017453292519943278,AUTHORITY["EPSG","9122"]],AXIS["Lat",NORTH],AXIS["Lon",EAST],AUTHORITY["EPSG","4326"]],PROJECTION["Popular Visualisation Pseudo Mercator",AUTHORITY["EPSG","1024"]],PARAMETER["Latitude of natural origin",0,AUTHORITY["EPSG","8801"]],PARAMETER["Longitude of natural origin",0,AUTHORITY["EPSG","8802"]],PARAMETER["False easting",0,AUTHORITY["EPSG","8806"]],PARAMETER["False northing",0,AUTHORITY["EPSG","8807"]],UNIT["metre",1,AUTHORITY["EPSG","9001"]],AXIS["X",EAST],AXIS["Y",NORTH],AUTHORITY["EPSG","3785"]]'
    DESCRIPTION 'Added for upstream compatibility'
  SQL

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
  def time_it
    t0 = Minitest.clock_time

    timeout = ENV.fetch("TEST_TIMEOUT", 10).to_i
    Timeout.timeout(timeout, Timeout::Error, "Test took over #{timeout} seconds to finish") do
      yield
    end
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

    def factory(srid: 3785)
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
