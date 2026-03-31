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

module ActiveRecord
  module ConnectionHandling # :nodoc:
    # Establishes a connection to the database that's used by all Active Record objects.
    def mysql2rgeo_connection(config)
      config = config.symbolize_keys
      config[:flags] ||= 0

      if config[:flags].kind_of? Array
        config[:flags].push "FOUND_ROWS"
      else
        config[:flags] |= Mysql2::Client::FOUND_ROWS
      end

      ConnectionAdapters::Mysql2RgeoAdapter.new(
        ConnectionAdapters::Mysql2RgeoAdapter.new_client(config),
        logger,
        nil,
        config,
      )
    end
  end

  module ConnectionAdapters
    class Mysql2RgeoAdapter < Mysql2Adapter
      ADAPTER_NAME = "Mysql2Rgeo"
      MINIMUM_SUPPORTED_VERSION = "8.0.0"

      include Mysql2Rgeo::SchemaStatements

      SPATIAL_COLUMN_OPTIONS =
        {
          geography:           { type: "geometry", geographic: true },
          geometry:            {},
          geometrycollection:  {},
          geometry_collection: { type: "geometrycollection" },
          linestring:          {},
          line_string:         { type: "linestring" },
          multilinestring:     {},
          multi_line_string:   { type: "multilinestring" },
          multipoint:          {},
          multi_point:         { type: "multipoint" },
          multipolygon:        {},
          multi_polygon:       { type: "multipolygon" },
          spatial:             { type: "geometry" },
          point:               {},
          polygon:             {},
          st_point:            { type: "point" },
          st_polygon:          { type: "polygon" }
        }.freeze

      # MySQL uses SRID 0 when a spatial column does not declare one explicitly.
      DEFAULT_SRID = 0

      def initialize(connection, logger, connection_options, config)
        super
        verify_supported_database_version!

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
        super.merge(
          geometry:            { name: "geometry" },
          geometrycollection:  { name: "geometrycollection" },
          line_string:         { name: "linestring" },
          linestring:          { name: "linestring" },
          st_point:            { name: "point" },
          st_polygon:          { name: "polygon" },
          multi_line_string:   { name: "multilinestring" },
          multi_point:         { name: "multipoint" },
          multi_polygon:       { name: "multipolygon" },
          spatial:             { name: "geometry" },
          point:               { name: "point" },
          polygon:             { name: "polygon" }
        )
      end

      class << self

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
        m.register_type %r(^tinyint\(1\))i, Type::Boolean.new
      end

      def supports_spatial?
        !mariadb? && database_version >= MINIMUM_SUPPORTED_VERSION
      end

      def adapter_name
        ADAPTER_NAME
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
        def verify_supported_database_version!
          return if database_version >= MINIMUM_SUPPORTED_VERSION

          raise ActiveRecord::ConnectionNotEstablished,
                "#{ADAPTER_NAME} supports MySQL #{MINIMUM_SUPPORTED_VERSION}+ only (detected #{database_version})"
        end

        def type_map
          emulate_booleans ? TYPE_MAP_WITH_BOOLEAN : TYPE_MAP
        end
    end
  end
end
