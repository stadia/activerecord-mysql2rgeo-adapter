# frozen_string_literal: true

module ActiveRecord
  module ConnectionAdapters
    module Mysql2Rgeo
      module SchemaStatements
        # super: https://github.com/rails/rails/blob/master/activerecord/lib/active_record/connection_adapters/mysql/schema_statements.rb

        # override
        def indexes(table_name) #:nodoc:
          indexes = super
          # HACK(aleks, 06/15/18): MySQL 5 does not support prefix lengths for spatial indexes
          # https://dev.mysql.com/doc/refman/5.6/en/create-index.html
          indexes.select do |idx|
            idx.type == :spatial
          end.each { |idx| idx.is_a?(Struct) ? idx.lengths = {} : idx.instance_variable_set(:@lengths, {}) }
          indexes
        end

        # override
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

          %w[
            geometry
            geometrycollection
            point
            linestring
            polygon
            multipoint
            multilinestring
            multipolygon
          ].each do |geo_type|
            m.register_type(geo_type) do |sql_type|
              Type::Spatial.new(sql_type)
            end
          end
        end

        private

        # override
        def schema_creation
          Mysql2Rgeo::SchemaCreation.new(self)
        end

        # override
        def create_table_definition(*args, **options)
          Mysql2Rgeo::TableDefinition.new(self, *args, **options)
        end

        # override
        def new_column_from_field(table_name, field)
          type_metadata = fetch_type_metadata(field[:Type], field[:Extra])
          default, default_function = field[:Default], nil

          if type_metadata.type == :datetime && /\ACURRENT_TIMESTAMP(?:\([0-6]?\))?\z/i.match?(default)
            default, default_function = nil, default
          elsif type_metadata.extra == "DEFAULT_GENERATED"
            default = +"(#{default})" unless default.start_with?("(")
            default, default_function = nil, default
          end

          # {:dimension=>2, :has_m=>false, :has_z=>false, :name=>"latlon", :srid=>0, :type=>"GEOMETRY"}
          spatial = spatial_column_info(table_name).get(field[:Field], type_metadata.sql_type)

          SpatialColumn.new(
            field[:Field],
            default,
            type_metadata,
            field[:Null] == "YES",
            default_function,
            collation: field[:Collation],
            comment: field[:Comment].presence,
            spatial: spatial
          )
        end

        # memoize hash of column infos for tables
        def spatial_column_info(table_name)
          @spatial_column_info ||= {}
          @spatial_column_info[table_name.to_sym] = SpatialColumnInfo.new(self, table_name.to_s)
        end
      end
    end
  end
end
