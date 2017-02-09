module ActiveRecord  # :nodoc:
  module ConnectionAdapters  # :nodoc:
    module Mysql2Rgeo  # :nodoc:
      class TableDefinition < MySQL::TableDefinition  # :nodoc:
        include ColumnMethods

        # super: https://github.com/rails/rails/blob/master/activerecord/lib/active_record/connection_adapters/abstract/schema_definitions.rb
        def new_column_definition(name, type, options)
          if (info = Mysql2RgeoAdapter.spatial_column_options(type.to_sym))
            if (limit = options.delete(:limit))
              options.merge!(limit) if limit.is_a?(::Hash)
            end

            geo_type = ColumnDefinition.geo_type(options[:type] || type || info[:type])
            base_type = info[:type] || :geometry

            # puts name.dup << " - " << type.to_s << " - " << options.to_s << " :: " << geo_type.to_s << " - " << base_type.to_s

            column = super(name, geo_type.downcase.to_sym, options)
            column.spatial_type = geo_type
            column.srid = options[:srid]
          else
            column = super(name, type, options)
          end

          column
        end

        private

        def create_column_definition(name, type)
          if Mysql2RgeoAdapter.spatial_column_options(type.to_sym)
            Mysql2Rgeo::ColumnDefinition.new(name, type)
          else
            super
          end
        end
      end

      class ColumnDefinition < MySQL::ColumnDefinition
        # needs to accept the spatial type? or figure out from limit ?

        def self.geo_type(type = "GEOMETRY")
          g_type = type.to_s.delete("_").upcase
          return "POINT" if g_type == "POINT"
          return "POLYGON" if g_type == "POLYGON"
          g_type
        end

        def spatial_type
          @spatial_type
        end

        def spatial_type=(value)
          @spatial_type = value.to_s
        end

        def srid
          if @srid
            @srid.to_i
          else
            Mysql2RgeoAdapter::DEFAULT_SRID
          end
        end

        def srid=(value)
          @srid = value
        end
      end

      SpatialIndexDefinition = Struct.new(*IndexDefinition.members, :spatial)
    end
  end
end
