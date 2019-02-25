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

        def geometry_collection(name, options = {})
          column(name, :geometrycollection, options)
        end
        alias geometrycollection geometry_collection

        def line_string(name, options = {})
          column(name, :linestring, options)
        end
        alias linestring line_string

        def multi_line_string(name, options = {})
          column(name, :multilinestring, options)
        end
        alias multilinestring multi_line_string

        def multi_point(name, options = {})
          column(name, :multipoint, options)
        end
        alias multipoint multi_point

        def multi_polygon(name, options = {})
          column(name, :multipolygon, options)
        end
        alias multipolygon multi_polygon

        def point(name, options = {})
          column(name, :point, options)
        end

        def polygon(name, options = {})
          column(name, :polygon, options)
        end
      end
    end

    MySQL::Table.include Mysql2Rgeo::ColumnMethods
  end
end
