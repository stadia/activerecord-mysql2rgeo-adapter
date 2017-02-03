# The activerecord-mysql2rgeo-adapter gem installs the *postgis*
# connection adapter into ActiveRecord.

# :stopdoc:

require "active_record/connection_adapters/mysql2_adapter"
require "rgeo/active_record"
require "active_record/connection_adapters/mysql2rgeo/version"
require "active_record/connection_adapters/mysql2rgeo/column_methods"
require "active_record/connection_adapters/mysql2rgeo/schema_statements"
require "active_record/connection_adapters/mysql2rgeo/spatial_table_definition"
require "active_record/connection_adapters/mysql2rgeo/spatial_column"
require "arel/visitors/bind_visitor"
require "active_record/connection_adapters/mysql2rgeo/arel_tosql"
require "active_record/connection_adapters/mysql2rgeo/setup"
require "active_record/type/spatial"
require "active_record/connection_adapters/mysql2rgeo/create_connection"

::ActiveRecord::ConnectionAdapters::Mysql2Rgeo.initial_setup

# :startdoc:

module ActiveRecord
  module ConnectionAdapters
    class Mysql2RgeoAdapter < Mysql2Adapter
      include Mysql2Rgeo::SchemaStatements

      SPATIAL_COLUMN_OPTIONS =
        {
          geometry:            {},
          geometry_collection: {},
          geometrycollection:  {},
          line_string:         {},
          linestring:          {},
          multi_line_string:   {},
          multilinestring:     {},
          multi_point:         {},
          multipoint:          {},
          multi_polygon:       {},
          multipolygon:        {},
          spatial:             {},
          point:               {},
          polygon:             {},
        }.freeze

      # http://postgis.17.x6.nabble.com/Default-SRID-td5001115.html
      DEFAULT_SRID = 0

      ADAPTER_NAME = 'Mysql2Rgeo'.freeze

      def initialize(connection, logger, connection_options, config)
        super

        @visitor = Arel::Visitors::Mysql2Rgeo.new(self)

        if self.class.type_cast_config_to_boolean(config.fetch(:prepared_statements) { true })
          @prepared_statements = true
          @visitor.extend(DetermineIfPreparableVisitor)
        else
          @prepared_statements = false
        end
      end

      def self.spatial_column_options(key)
        SPATIAL_COLUMN_OPTIONS[key]
      end

      def default_srid
        DEFAULT_SRID
      end

      def indexes(table_name, name = nil) #:nodoc:
        indexes = []
        current_index = nil
        execute_and_free("SHOW KEYS FROM #{quote_table_name(table_name)}", 'SCHEMA') do |result|
          each_hash(result) do |row|
            if current_index != row[:Key_name]
              next if row[:Key_name] == 'PRIMARY' # skip the primary key
              current_index = row[:Key_name]

              mysql_index_type = row[:Index_type].downcase.to_sym
              index_type  = INDEX_TYPES.include?(mysql_index_type)  ? mysql_index_type : nil
              index_using = INDEX_USINGS.include?(mysql_index_type) ? mysql_index_type : nil
              indexes << IndexDefinition.new(row[:Table], row[:Key_name], row[:Non_unique].to_i == 0, [], {}, nil, nil, index_type, index_using, row[:Index_comment].presence)
              if row[:Index_type] != 'SPATIAL'
                indexes << IndexDefinition.new(row[:Table], row[:Key_name], row[:Non_unique].to_i == 0, [], [], nil, nil, index_type, index_using, row[:Index_comment].presence)
              else
                indexes << RGeo::ActiveRecord::SpatialIndexDefinition.new(row[:Table], row[:Key_name], row[:Non_unique] == 0, [], [], row[:Index_type] == 'SPATIAL')
              end
            end

            indexes.last.columns << row[:Column_name]
            indexes.last.lengths << row[:Sub_part] unless indexes.last.try(:spatial)
          end
        end

        indexes
      end

      def quote(value, column = nil)
        if RGeo::Feature::Geometry.check_type(value)
          "ST_GeomFromWKB(0x#{::RGeo::WKRep::WKBGenerator.new(:hex_format => true).generate(value)},#{value.srid})"
        else
          super
        end
      end
    end
  end
end
