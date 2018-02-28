# The activerecord-mysql2rgeo-adapter gem installs the *mysql2rgeo*
# connection adapter into ActiveRecord.

# :stopdoc:

require "rgeo/active_record"

# autoload AbstractAdapter to avoid circular require and void context warnings
module ActiveRecord
  module ConnectionAdapters
    AbstractAdapter
  end
end

require "active_record/connection_adapters/mysql2_adapter"
require "active_record/connection_adapters/mysql2rgeo/version"
require "active_record/connection_adapters/mysql2rgeo/column_methods"
require "active_record/connection_adapters/mysql2rgeo/schema_statements"
require "active_record/connection_adapters/mysql2rgeo/spatial_table_definition"
require "active_record/connection_adapters/mysql2rgeo/spatial_column"
require "active_record/connection_adapters/mysql2rgeo/spatial_expressions"
require "active_record/connection_adapters/mysql2rgeo/arel_tosql"
require "active_record/type/spatial"
require "active_record/connection_adapters/mysql2rgeo/create_connection"

# :startdoc:

module ActiveRecord
  module ConnectionAdapters
    class Mysql2RgeoAdapter < Mysql2Adapter
      include Mysql2Rgeo::SchemaStatements

      SPATIAL_COLUMN_OPTIONS =
        {
          geometry: {},
          geometrycollection: {},
          linestring: {},
          multilinestring: {},
          multipoint: {},
          multipolygon: {},
          spatial: { type: "geometry" },
          point: {},
          polygon: {}
        }.freeze

      # http://postgis.17.x6.nabble.com/Default-SRID-td5001115.html
      DEFAULT_SRID = 0

      def initialize(connection, logger, connection_options, config)
        super

        @visitor = Arel::Visitors::Mysql2Rgeo.new(self)
        @visitor.extend(DetermineIfPreparableVisitor) if self.class.type_cast_config_to_boolean(config.fetch(:prepared_statements) { true })
      end

      def adapter_name
        "Mysql2Rgeo".freeze
      end

      def self.spatial_column_options(key)
        SPATIAL_COLUMN_OPTIONS[key]
      end

      def default_srid
        DEFAULT_SRID
      end

      def supports_spatial?
        !mariadb? && version >= "5.7.6"
      end

      # Returns an array of indexes for the given table.
      def indexes(table_name, name = nil) #:nodoc:
        if name
          ActiveSupport::Deprecation.warn(<<-MSG.squish)
            Passing name to #indexes is deprecated without replacement.
          MSG
        end

        indexes = []
        current_index = nil
        execute_and_free("SHOW KEYS FROM #{quote_table_name(table_name)}", "SCHEMA") do |result|
          each_hash(result) do |row|
            if current_index != row[:Key_name]
              next if row[:Key_name] == "PRIMARY" # skip the primary key
              current_index = row[:Key_name]

              mysql_index_type = row[:Index_type].downcase.to_sym
              index_type = INDEX_TYPES.include?(mysql_index_type) ? mysql_index_type : nil
              index_using = INDEX_USINGS.include?(mysql_index_type) ? mysql_index_type : nil
              indexes << IndexDefinition.new(row[:Table], row[:Key_name], row[:Non_unique].to_i == 0, [], {}, nil, nil, index_type, index_using, row[:Index_comment].presence)
            end

            indexes.last.columns << row[:Column_name]
            indexes.last.lengths.merge!(row[:Column_name] => row[:Sub_part].to_i) if row[:Sub_part] && mysql_index_type != :spatial
          end
        end

        indexes
      end

      def quote(value)
        if RGeo::Feature::Geometry.check_type(value)
          "ST_GeomFromWKB(0x#{RGeo::WKRep::WKBGenerator.new(hex_format: true, little_endian: true).generate(value)},#{value.srid})"
        else
          super
        end
      end
    end
  end
end
