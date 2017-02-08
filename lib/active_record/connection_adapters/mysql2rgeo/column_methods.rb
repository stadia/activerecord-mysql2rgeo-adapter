module ActiveRecord
  module ConnectionAdapters
    module Mysql2Rgeo
      module ColumnMethods
        def spatial(name, options = {})
          raise "You must set a type. For example: 't.spatial :object1, limit: { type: 'point' }'" if options[:limit].blank? || options[:limit][:type].blank?
          column(name, options[:limit][:type], options)
        end

        def geography(*args, **options)
          args.each { |name| column(name, :geometry, options) }
        end

        def geometry(*args, multi: false, **options)
          multi ? multi_geometry(*args, **options) : args.each { |name| column(name, :geometry, options) }
        end

        def multi_geometry(*args, **options)
          args.each { |name| column(name, :geometrycollection, options) }
        end

        def point(*args, multi: false, **options)
          multi ? multi_point(*args, **options) : args.each { |name| column(name, :point, options) }
        end

        def multi_point(*args, **options)
          args.each { |name| column(name, :multipoint, options) }
        end

        def linestring(*args, multi: false, **options)
          multi ? multi_linestring(*args, **options) : args.each { |name| column(name, :linestring, options) }
        end

        def multi_linestring(*args, **options)
          args.each { |name| column(name, :multilinestring, options) }
        end

        def polygon(*args, multi: false, **options)
          type = multi ? :multipolygon : :polygon
          args.each { |name| column(name, type, options) }
        end

        def multi_polygon(*args, **options)
          polygon(args, true, options)
        end
      end

      MySQL::Table.send(:include, ColumnMethods)
    end
  end
end
