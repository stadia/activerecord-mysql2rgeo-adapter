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
            type = 'geometry' if type.to_s == 'spatial'
            type = type.to_s.gsub('_', '').upcase
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
              geography: { name: "geography" },
              geometry: { name: "geometry" },
              geometry_collection: { name: "geometry_collection" },
              line_string: { name: "line_string" },
              multi_line_string: { name: "multi_line_string" },
              multi_point: { name: "multi_point" },
              multi_polygon: { name: "multi_polygon" },
              spatial: { name: "geometry", limit: { type: :point } },
              point: { name: "point" },
              polygon: { name: "polygon" }
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
          register_class_with_limit m, %r(geometry)i, Type::Spatial
          m.alias_type %r(point)i, 'geometry'
          m.alias_type %r(linestring)i, 'geometry'
          m.alias_type %r(polygon)i, 'geometry'

        end
        # def initialize_type_map(map)
        #   super
        #
        #   %w(
        #     geography
        #     geometry
        #     geometry_collection
        #     line_string
        #     multi_line_string
        #     multi_point
        #     multi_polygon
        #     point
        #     polygon
        #   ).each do |geo_type|
        #     map.register_type(geo_type) do |sql_type|
        #       Type::Spatial.new(sql_type)
        #     end
        #   end
        # end
      end
    end
  end
end
