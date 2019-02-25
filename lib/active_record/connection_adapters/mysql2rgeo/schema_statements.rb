# frozen_string_literal: true

module ActiveRecord
  module ConnectionAdapters
    module Mysql2Rgeo
      module SchemaStatements
        # override
        def indexes(table_name) #:nodoc:
          indexes = super
          # HACK(aleks, 06/15/18): MySQL 5 does not support prefix lengths for spatial indexes
          # https://dev.mysql.com/doc/refman/5.6/en/create-index.html
          indexes.select { |idx| idx.type == :spatial }.each { |idx| idx.is_a?(Struct) ? idx.lengths = {} : idx.instance_variable_set(:@lengths, {}) }
          indexes
        end

        def type_to_sql(type, limit: nil, precision: nil, scale: nil, unsigned: nil, **) # :nodoc:
          if (info = RGeo::ActiveRecord.geometric_type_from_name(type.to_s.delete("_")))
            type = limit[:type] || type if limit.is_a?(::Hash)
            type = type.to_s.delete("_").upcase
          end
          super
        end

        # override
        def native_database_types
          # Add spatial types
          # Reference: https://dev.mysql.com/doc/refman/5.6/en/spatial-type-overview.html
          super.merge(
            geometry:            { name: "geometry" },
            geometrycollection:  { name: "geometrycollection" },
            linestring:          { name: "linestring" },
            multi_line_string:   { name: "multilinestring" },
            multi_point:         { name: "multipoint" },
            multi_polygon:       { name: "multipolygon" },
            spatial:             { name: "geometry" },
            point:               { name: "point" },
            polygon:             { name: "polygon" }
          )
        end

        def initialize_type_map(m = type_map)
          super
          %w(
            geometry
            geometrycollection
            point
            linestring
            polygon
            multipoint
            multilinestring
            multipolygon
          ).each do |geo_type|
            m.register_type(geo_type, Type::Spatial.new(geo_type))
          end
        end

        private

        # override
        def create_table_definition(*args)
          Mysql2Rgeo::TableDefinition.new(*args)
        end

        # override
        def new_column_from_field(table_name, field)
          type_metadata = fetch_type_metadata(field[:Type], field[:Extra])
          if type_metadata.type == :datetime && /\ACURRENT_TIMESTAMP(?:\([0-6]?\))?\z/i.match?(field[:Default])
            default, default_function = nil, field[:Default]
          else
            default, default_function = field[:Default], nil
          end

          SpatialColumn.new(
              field[:Field],
              default,
              type_metadata,
              field[:Null] == "YES",
              table_name,
              default_function,
              field[:Collation],
              comment: field[:Comment].presence
          )
        end
      end
    end
  end
end
