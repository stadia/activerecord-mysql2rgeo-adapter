# frozen_string_literal: true

module ActiveRecord # :nodoc:
  module ConnectionAdapters # :nodoc:
    module Mysql2Rgeo # :nodoc:
      class SpatialColumn < ConnectionAdapters::MySQL::Column # :nodoc:
        def initialize(name, default, sql_type_metadata = nil, null = true, default_function = nil, collation: nil, comment: nil, spatial: nil, array: false, **)
          @sql_type_metadata = sql_type_metadata
          @array = array
          @geographic = !!(sql_type_metadata&.sql_type =~ /geography\(/i)
          if spatial
            # This case comes from an entry in the geometry_columns table
            set_geometric_type_from_name(spatial[:type])
            @srid = spatial[:srid].to_i
            @has_z = !!spatial[:has_z]
            @has_m = !!spatial[:has_m]
            @geographic = !!spatial[:geographic] || @geographic
          elsif @geographic
            @srid = 4326
            @has_z = @has_m = false
            build_from_sql_type(sql_type_metadata.sql_type)
          elsif sql_type =~ /geometry|point|linestring|polygon/i
            build_from_sql_type(sql_type_metadata.sql_type)
          elsif sql_type_metadata.sql_type =~ /geometry|point|linestring|polygon/i
            # A geometry column with no geometry_columns entry.
            # @geometric_type = geo_type_from_sql_type(sql_type)
            build_from_sql_type(sql_type_metadata.sql_type)
          end
          super(name, default, sql_type_metadata, null, default_function, collation: collation, comment: comment)
          if spatial?
            if @srid
              @limit = { type: limit_type_name, srid: @srid }
              @limit[:geographic] = true if geographic?
              @limit[:has_z] = true if has_z?
              @limit[:has_m] = true if has_m?
            end
          end
        end

        attr_reader :geometric_type, :srid

        def array
          @array || false
        end
        alias array? array

        def has_z
          spatial? ? (@has_z || false) : nil
        end

        def has_m
          spatial? ? (@has_m || false) : nil
        end

        def geographic
          spatial? ? (@geographic || false) : nil
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

        SPATIAL_ATTRIBUTES = %w[geographic geometric_type has_m has_z srid limit].freeze

        def init_with(coder)
          SPATIAL_ATTRIBUTES.each { |attr| instance_variable_set(:"@#{attr}", coder[attr]) }
          super
        end

        def encode_with(coder)
          SPATIAL_ATTRIBUTES.each { |attr| coder[attr] = instance_variable_get(:"@#{attr}") }
          super
        end

        def ==(other)
          other.is_a?(SpatialColumn) &&
            super &&
            array == other.array &&
            SPATIAL_ATTRIBUTES.all? { |attr| public_send(attr) == other.public_send(attr) }
        end
        alias eql? ==

        def hash
          SPATIAL_ATTRIBUTES.reduce(SpatialColumn.hash ^ super.hash ^ array.hash) { |h, attr| h ^ public_send(attr).hash }
        end

        private

        def set_geometric_type_from_name(name)
          @geometric_type = RGeo::ActiveRecord.geometric_type_from_name(name) || RGeo::Feature::Geometry
          @geo_type_name = ActiveRecord::Type::Spatial.normalize_geo_type(name)
        end

        def build_from_sql_type(sql_type)
          geo_type, @srid, @has_z, @has_m, @geographic = Type::Spatial.parse_sql_type(sql_type)
          set_geometric_type_from_name(geo_type)
        end

        def limit_type_name
          type_name = @geo_type_name || geometric_type.type_name.underscore
          case type_name
          when "point", "polygon"
            "st_#{type_name}"
          when "linestring"
            "line_string"
          when "multilinestring"
            "multi_line_string"
          when "multipoint"
            "multi_point"
          when "multipolygon"
            "multi_polygon"
          else
            type_name
          end
        end
      end
    end
  end
end
