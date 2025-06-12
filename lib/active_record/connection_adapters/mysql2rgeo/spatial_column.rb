# frozen_string_literal: true

module ActiveRecord # :nodoc:
  module ConnectionAdapters # :nodoc:
    module Mysql2Rgeo # :nodoc:
      class SpatialColumn < ConnectionAdapters::MySQL::Column # :nodoc:
        def initialize(name, default, sql_type_metadata = nil, null = true, default_function = nil, collation: nil, comment: nil,
spatial: nil, **)
          @sql_type_metadata = sql_type_metadata
          if spatial
            # This case comes from an entry in the geometry_columns table
            set_geometric_type_from_name(spatial[:type])
            @srid = spatial[:srid].to_i
          elsif sql_type =~ /geometry|point|linestring|polygon/i
            build_from_sql_type(sql_type_metadata.sql_type)
          elsif sql_type_metadata.sql_type =~ /geometry|point|linestring|polygon/i
            # A geometry column with no geometry_columns entry.
            # @geometric_type = geo_type_from_sql_type(sql_type)
            build_from_sql_type(sql_type_metadata.sql_type)
          end
          super(name, default, sql_type_metadata, null, default_function, collation: collation, comment: comment)
          if spatial? && @srid
            @limit = { type: geometric_type.type_name.underscore, srid: @srid }
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

        alias geographic? geographic
        alias has_z? has_z
        alias has_m? has_m

        def multi?
          /^(geometrycollection|multi)/i.match?(sql_type)
        end

        def limit
          spatial? ? @limit : super
        end

        def spatial?
          %i[geometry geography].include?(@sql_type_metadata.type)
        end

        private

        def set_geometric_type_from_name(name)
          @geometric_type = RGeo::ActiveRecord.geometric_type_from_name(name) || RGeo::Feature::Geometry
        end

        def build_from_sql_type(sql_type)
          geo_type, @srid = Type::Spatial.parse_sql_type(sql_type)
          set_geometric_type_from_name(geo_type)
        end
      end
    end
  end
end
