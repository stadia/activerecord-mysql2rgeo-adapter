module ActiveRecord
  module ConnectionAdapters
    module Mysql2Rgeo
      module SchemaStatements
        # override
        def new_column(*args)
          SpatialColumn.new(*args)
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
            spatial: { name: "geometry" },
            geometry: { name: "geometry" },
            geometrycollection: { name: "geometrycollection" },
            point: { name: "point" },
            linestring: { name: "linestring" },
            polygon: { name: "polygon" },
            multipoint: { name: "multipoint" },
            multilinestring: { name: "multilinestring" },
            multipolygon: { name: "multipolygon" },
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
      end
    end
  end
end
