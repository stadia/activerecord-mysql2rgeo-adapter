module ActiveRecord
  module ConnectionAdapters
    module Mysql2Rgeo
      module SchemaStatements
        # override
        def new_column(*args)
          SpatialColumn.new(*args)
        end

        def type_to_sql(type, limit = nil, precision = nil, scale = nil, array = nil)
          if (info = spatial_column_constructor(type.to_sym))
            type = limit[:type] || type if limit.is_a?(::Hash)
            type = "geometry" if type.to_s == "spatial"
            type = type.to_s.delete("_").upcase
          end
          super(type, limit, precision, scale, array)
        end

        def spatial_column_constructor(name)
          ::RGeo::ActiveRecord::DEFAULT_SPATIAL_COLUMN_CONSTRUCTORS[name]
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

        def type_cast(value, column = nil)
          super
        rescue TypeError
          value.to_s
        end

        def initialize_type_map(m)
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
