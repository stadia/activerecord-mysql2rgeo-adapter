module ActiveRecord
  module ConnectionAdapters
    module Mysql2Rgeo
      module SchemaStatements
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
                case mysql_index_type
                when :fulltext, :spatial
                  index_type = mysql_index_type
                when :btree, :hash
                  index_using = mysql_index_type
                end
                indexes << IndexDefinition.new(row[:Table], row[:Key_name], row[:Non_unique].to_i == 0, [], {}, nil, nil, index_type, index_using, row[:Index_comment].presence)
              end

              indexes.last.columns << row[:Column_name]
              indexes.last.lengths.merge!(row[:Column_name] => row[:Sub_part].to_i) if row[:Sub_part] && mysql_index_type != :spatial
            end
          end

          indexes
        end

        # override
        def new_column(*args)
          SpatialColumn.new(*args)
        end

        def type_to_sql(type, limit: nil, precision: nil, scale: nil, unsigned: nil, **) # :nodoc:
          if (info = RGeo::ActiveRecord.geometric_type_from_name(type.to_s.delete("_")))
            type = limit[:type] || type if limit.is_a?(::Hash)
            type = :geometry if type.eql? :spatial
            type = type.to_s.delete("_").upcase
          end
          super
        end

        # override
        def native_database_types
          # Add spatial types
          super.merge(
            geometry: { name: "geometry" },
            point: { name: "point" },
            linestring: { name: "linestring" },
            polygon: { name: "polygon" },
            multi_geometry: { name: "geometrycollection" },
            multi_point: { name: "multipoint" },
            multi_linestring: { name: "multilinestring" },
            multi_polygon: { name: "multipolygon" },
            spatial: { name: "geometry", limit: { type: :point } }
          )
        end

        # override
        def create_table_definition(*args)
          Mysql2Rgeo::TableDefinition.new(*args)
        end

        def initialize_type_map(m = type_map)
          super
          %w(
            geometry
            point
            linestring
            polygon
            geometrycollection
            multipoint
            multilinestring
            multipolygon
          ).each do |geo_type|
            m.register_type(geo_type, Type::Spatial.new(geo_type))
          end
        end
      end
    end
  end
end
