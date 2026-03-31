# frozen_string_literal: true

# The activerecord-mysql2rgeo-adapter gem installs the *mysql2rgeo*
# connection adapter into ActiveRecord.

# :stopdoc:

require "rgeo/active_record"

require "active_record/connection_adapters"
require "active_record/connection_adapters/mysql2_adapter"
require "active_record/connection_adapters/mysql2rgeo/version"
require "active_record/connection_adapters/mysql2rgeo/column_methods"
require "active_record/connection_adapters/mysql2rgeo/schema_creation"
require "active_record/connection_adapters/mysql2rgeo/schema_statements"
require "active_record/connection_adapters/mysql2rgeo/spatial_table_definition"
require "active_record/connection_adapters/mysql2rgeo/spatial_column"
require "active_record/connection_adapters/mysql2rgeo/spatial_column_info"
require "active_record/connection_adapters/mysql2rgeo/spatial_expressions"
require "active_record/connection_adapters/mysql2rgeo/arel_tosql"
require "active_record/type/spatial"

# :startdoc:

ActiveRecord::ConnectionAdapters.register(
  "mysql2rgeo",
  "ActiveRecord::ConnectionAdapters::Mysql2RgeoAdapter",
  "active_record/connection_adapters/mysql2rgeo_adapter"
)

module ActiveRecord
  module ConnectionHandling # :nodoc:
    # Establishes a connection to the database that's used by all Active Record objects.
    def mysql2rgeo_connection(config)
      config = config.symbolize_keys
      config[:flags] ||= 0
      config[:database_timezone] ||= ConnectionAdapters::AbstractAdapter.validate_default_timezone(config[:default_timezone])

      if config[:flags].is_a? Array
        config[:flags].push "FOUND_ROWS"
      else
        config[:flags] |= Mysql2::Client::FOUND_ROWS
      end

      ConnectionAdapters::Mysql2RgeoAdapter.new(
        ConnectionAdapters::Mysql2RgeoAdapter.new_client(config),
        logger,
        nil,
        config
      )
    end
  end

  module ConnectionAdapters
    class Mysql2RgeoAdapter < Mysql2Adapter
      ADAPTER_NAME = "Mysql2Rgeo"

      include Mysql2Rgeo::SchemaStatements

      SPATIAL_COLUMN_OPTIONS =
        {
          geography: { type: "geometry", geographic: true },
          geometry: {},
          geometrycollection: {},
          geometry_collection: { type: "geometrycollection" },
          linestring: {},
          line_string: { type: "linestring" },
          multilinestring: {},
          multi_line_string: { type: "multilinestring" },
          multipoint: {},
          multi_point: { type: "multipoint" },
          multipolygon: {},
          multi_polygon: { type: "multipolygon" },
          spatial: { type: "geometry" },
          point: {},
          polygon: {},
          st_point: { type: "point" },
          st_polygon: { type: "polygon" }
        }.freeze

      DEFAULT_SRID = 0

      def initialize(...)
        super

        @visitor = Arel::Visitors::Mysql2Rgeo.new(self)
      end

      def self.spatial_column_options(key)
        SPATIAL_COLUMN_OPTIONS[key]
      end

      def default_srid
        DEFAULT_SRID
      end

      def native_database_types
        # Add spatial types
        # Reference: https://dev.mysql.com/doc/refman/5.6/en/spatial-type-overview.html
        self.class.native_database_types
      end

      class << self
        def native_database_types
          super.merge(
            geography: { name: "geometry" },
            geometry: { name: "geometry" },
            geometrycollection: { name: "geometrycollection" },
            line_string: { name: "linestring" },
            linestring: { name: "linestring" },
            st_point: { name: "point" },
            st_polygon: { name: "polygon" },
            multi_line_string: { name: "multilinestring" },
            multi_point: { name: "multipoint" },
            multi_polygon: { name: "multipolygon" },
            spatial: { name: "geometry" },
            point: { name: "point" },
            polygon: { name: "polygon" }
          )
        end

        def extended_type_map(emulate_booleans:, default_timezone: nil)
          Type::TypeMap.new(emulate_booleans ? TYPE_MAP_WITH_BOOLEAN : TYPE_MAP).tap do |m|
            register_class_with_precision m, /\A[^(]*time/i, Type::Time, timezone: default_timezone
            register_class_with_precision m, /\A[^(]*datetime/i, Type::DateTime, timezone: default_timezone
            m.alias_type(/\A[^(]*timestamp/i, "datetime")
          end
        end

        private

        def initialize_type_map(m)
          super

          {
            "geography" => "geometry",
            "geometry" => "geometry",
            "geometry_collection" => "geometrycollection",
            "line_string" => "linestring",
            "multi_line_string" => "multilinestring",
            "multi_point" => "multipoint",
            "multi_polygon" => "multipolygon",
            "st_point" => "point",
            "st_polygon" => "polygon",
          }.each do |registered_type, geo_type|
            m.register_type(registered_type) do |sql_type|
              Type::Spatial.new(sql_type.to_s, geo_type: geo_type)
            end
          end

          [
            /\Ageometry(?:\(.*\))?\z/i,
            /\Ageography(?:\(.*\))?\z/i,
            /\Apoint(?:\s.*)?\z/i,
            /\Alinestring(?:\s.*)?\z/i,
            /\Apolygon(?:\s.*)?\z/i,
            /\Amultipoint(?:\s.*)?\z/i,
            /\Amultilinestring(?:\s.*)?\z/i,
            /\Amultipolygon(?:\s.*)?\z/i,
            /\Ageometrycollection(?:\s.*)?\z/i,
          ].each do |pattern|
            m.register_type(pattern) do |sql_type|
              Type::Spatial.new(sql_type.to_s)
            end
          end

          {
            st_point: "point",
            st_polygon: "polygon",
            line_string: "linestring",
            multi_line_string: "multilinestring",
            multi_point: "multipoint",
            multi_polygon: "multipolygon",
          }.each do |alias_type, geo_type|
            ActiveRecord::Type.register(alias_type) do |_, **kwargs|
              Type::Spatial.new(geo_type, geo_type: geo_type, **kwargs)
            end
          end
        end
      end

      TYPE_MAP = Type::TypeMap.new.tap { |m| initialize_type_map(m) }
      TYPE_MAP_WITH_BOOLEAN = Type::TypeMap.new(TYPE_MAP).tap do |m|
        m.register_type(/^tinyint\(1\)/i, Type::Boolean.new)
      end

      def supports_spatial?
        !mariadb? && version >= "5.7.6"
      end

      def supports_partitioned_indexes?
        false
      end

      def adapter_name
        "Mysql2Rgeo"
      end

      def quote(value)
        dbval = value.try(:value_for_database) || value
        if RGeo::Feature::Geometry.check_type(dbval)
          wkt = RGeo::WKRep::WKTGenerator.new(tag_format: :wkt11, emit_ewkt_srid: false).generate(dbval)
          if dbval.srid == 4326
            "ST_GeomFromText(#{super(wkt)}, #{dbval.srid}, 'axis-order=long-lat')"
          else
            "ST_GeomFromText(#{super(wkt)}, #{dbval.srid})"
          end
        else
          super
        end
      end

      def quote_default_expression(value, column) # :nodoc:
        return super unless column.respond_to?(:spatial?) && column.spatial?

        value = lookup_cast_type(column.sql_type).serialize(value)
        hex = RGeo::WKRep::WKBGenerator.new(
          hex_format: true,
          little_endian: true,
          type_format: :wkb11,
          emit_ewkb_srid: false
        ).generate(value).upcase
        "(ST_GeomFromWKB(x'#{hex}', #{value.srid}))"
      end

      private

      def type_map
        if (key = extended_type_map_key)
          self.class::EXTENDED_TYPE_MAPS.compute_if_absent(key) do
            self.class.extended_type_map(**key)
          end
        else
          emulate_booleans ? TYPE_MAP_WITH_BOOLEAN : TYPE_MAP
        end
      end
    end
  end
end
