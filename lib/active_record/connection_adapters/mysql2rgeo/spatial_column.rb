module ActiveRecord # :nodoc:
  module ConnectionAdapters # :nodoc:
    module Mysql2Rgeo # :nodoc:
      class SpatialColumn < ConnectionAdapters::MySQL::Column # :nodoc:
        # sql_type examples:
        #   "Geometry"
        #   "Geography"
        # cast_type example classes:
        #   OID::Spatial
        #   OID::Integer
        def initialize(name, default, sql_type_metadata = nil, null = true, table_name = nil, default_function = nil, collation = nil, comment: nil)
          if sql_type =~ /geometry|point|linestring|polygon/i
            build_from_sql_type(sql_type_metadata.sql_type)
          elsif sql_type_metadata.sql_type =~ /geometry|point|linestring|polygon/i
            # A geometry column with no geometry_columns entry.
            # @geometric_type = geo_type_from_sql_type(sql_type)
            build_from_sql_type(sql_type_metadata.sql_type)
          end
          super(name, default, sql_type_metadata, null, table_name, default_function, collation)
          @comment = comment
          if spatial?
            if @srid
              @limit = { type: @geometric_type.type_name.underscore }
              @limit[:srid] = @srid if @srid
            end
          end
        end

        attr_reader :geometric_type, :srid

        def has_z
          false
        end

        def has_m
          false
        end

        def geographic
          false
        end

        alias :has_z? :has_z
        alias :has_m? :has_m
        alias :geographic? :geographic

        def limit
          if spatial?
            @limit
          else
            super
          end
        end

        def klass
          type == :spatial ? ::RGeo::Feature::Geometry : super
        end

        def spatial?
          !@geometric_type.nil?
        end

        private
        def set_geometric_type_from_name(name)
          @geometric_type = RGeo::ActiveRecord.geometric_type_from_name(name) || RGeo::Feature::Geometry
        end

        def build_from_sql_type(sql_type)
          geo_type, @srid, @has_z, @has_m = Type::Spatial.parse_sql_type(sql_type)
          set_geometric_type_from_name(geo_type)
        end
      end
    end
  end
end
