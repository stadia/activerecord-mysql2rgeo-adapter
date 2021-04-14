# frozen_string_literal: true

module ActiveRecord # :nodoc:
  module ConnectionAdapters # :nodoc:
    module Mysql2Rgeo # :nodoc:
      # Do spatial sql queries for column info and memoize that info.
      class SpatialColumnInfo
        def initialize(adapter, table_name)
          @adapter = adapter
          @table_name = table_name
        end

        def all
          info = if @adapter.supports_expression_index?
                   @adapter.query(
                     "SELECT column_name, srs_id, column_type FROM INFORMATION_SCHEMA.Columns WHERE table_name='#{@table_name}'"
                   )
                 else
                   @adapter.query(
                     "SELECT column_name, 0, column_type FROM INFORMATION_SCHEMA.Columns WHERE table_name='#{@table_name}'"
                   )
                 end

          result = {}
          info.each do |row|
            name = row[0]
            type = row[2]
            type.sub!(/m$/, "")
            result[name] = {
              name:      name,
              srid:      row[1].to_i,
              type:      type,
            }
          end
          result
        end

        # do not query the database for non-spatial columns/tables
        def get(column_name, type)
          return unless Mysql2RgeoAdapter.spatial_column_options(type.to_sym)

          @spatial_column_info ||= all
          @spatial_column_info[column_name]
        end
      end
    end
  end
end
