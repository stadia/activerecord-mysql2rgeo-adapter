# frozen_string_literal: true

require "bundler/setup"
Bundler.require :development
require "minitest/autorun"
require "minitest/pride"
require "minitest/excludes"

require "erb"
require "yaml"
require "byebug" if ENV["BYEBUG"]
require "activerecord-mysql2rgeo-adapter"
require "timeout"

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

ENV["ARCONN"] ||= "mysql2rgeo"

def ensure_mysql_test_databases!
  raw_config = YAML.safe_load(
    ERB.new(File.read(File.expand_path("database.yml", __dir__))).result,
    aliases: true
  )
  configs = raw_config.fetch("connections").fetch("mysql2rgeo")

  %w[arunit arunit2].each do |name|
    config = configs.fetch(name)
    Mysql2::Client.new(
      host: config["host"],
      port: config["port"].to_i,
      username: config["username"],
      password: config["password"]
    ).query("CREATE DATABASE IF NOT EXISTS `#{config['database']}`")
  end
end

ensure_mysql_test_databases!

# We need to require this before the original `cases/helper`
# to make sure we patch load schema before it runs.
require "support/load_schema_helper"

module LoadSchemaHelperExt
  # Postgis uses the postgresql specific schema.
  # We need to explicit that behavior.
  def load_postgis_specific_schema
    # silence verbose schema loading
    shh do
      load "schema/mysql_specific_schema.rb"

      ActiveRecord::FixtureSet.reset_cache
    end
  end

  def load_schema
    super
    load_postgis_specific_schema
  end

  private def shh
    original_stdout = $stdout
    $stdout = StringIO.new
    yield
  ensure
    $stdout = original_stdout
  end
end
LoadSchemaHelper.prepend(LoadSchemaHelperExt)

require "cases/helper"

ActiveRecord::SchemaDumper.ignore_tables = %w[
  layer
  raster_columns
  raster_overviews
  spatial_ref_sys
  topology
]

class SpatialModel < ActiveRecord::Base
end

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

if ENV["JSON_REPORTER"]
  puts "Generating JSON report: #{ENV['JSON_REPORTER']}"
  module Minitest
    class JSONReporter < StatisticsReporter
      def report
        super
        io.write(
          {
            seed: Minitest.seed,
            assertions: assertions,
            count: count,
            failed_tests: results.reject(&:skipped?), # .failure.message
            total_time: total_time,
            failures: failures,
            errors: errors,
            warnings: warnings,
            skips: skips,
          }.to_json
        )
      end
    end

    def self.plugin_json_reporter_init(*)
      reporter << JSONReporter.new(File.open(ENV["JSON_REPORTER"], "w"))
    end

    load_plugins
    extensions << "json_reporter"
  end
end

# Using '--fail-fast' may cause the rails plugin to raise Interrupt when recording
# a test. This would prevent other plugins from recording it. Hence we make sure
# that rails plugin is loaded last.
Minitest.load_plugins
if Minitest.extensions.include?("rails")
  Minitest.extensions.delete("rails")
  Minitest.extensions << "rails"
end
