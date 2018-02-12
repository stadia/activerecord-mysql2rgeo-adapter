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

            geo_type = ColumnDefinitionUtils.geo_type(options[:type] || type || info[:type])
            base_type = info[:type] || :geometry

            options[:spatial_type] = geo_type
            column = super(name, geo_type.downcase.to_sym, options)
          else
            column = super(name, type, options)
          end

          column
        end
      end

      SpatialIndexDefinition = Struct.new(*IndexDefinition.members, :spatial)

      module ColumnDefinitionUtils
        class << self
          def geo_type(type = "GEOMETRY")
            type.to_s.delete('_').upcase
          end

          def default_srid(options)
            options[:geographic] ? 4326 : Mysql2RgeoAdapter::DEFAULT_SRID
          end
        end
      end
    end
  end
end
