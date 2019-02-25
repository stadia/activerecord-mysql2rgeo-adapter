# frozen_string_literal: true

module ActiveRecord
  module ConnectionAdapters
    module Mysql2Rgeo
      module ColumnMethods
        def spatial(name, options = {})
          raise "You must set a type. For example: 't.spatial type: :st_point'" unless options[:type]

          column(name, options[:type], options)
        end

        def geometry(name, options = {})
          column(name, :geometry, options)
        end

        def geometrycollection(name, options = {})
          column(name, :geometrycollection, options)
        end
        alias geometry_collection geometrycollection

        def point(name, options = {})
          column(name, :point, options)
        end

        def multipoint(name, options = {})
          column(name, :multipoint, options)
        end
        alias multi_point multipoint

        def linestring(name, options = {})
          column(name, :linestring, options)
        end
        alias line_string linestring

        def multilinestring(name, options = {})
          column(name, :multilinestring, options)
        end
        alias multi_line_string multilinestring

        def polygon(name, options = {})
          column(name, :polygon, options)
        end

        def multipolygon(name, options = {})
          column(name, :multipolygon, options)
        end
        alias multi_polygon multipolygon
      end
    end

    MySQL::Table.include Mysql2Rgeo::ColumnMethods
  end
end
