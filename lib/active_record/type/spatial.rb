# frozen_string_literal: true

module ActiveRecord
  module Type
    class Spatial < Value # :nodoc:
      # sql_type is a string that comes from the database definition
      # examples:
      #   "geometry"
      #   "geography"
      #   "geometry NOT NULL"
      #   "geometry"
      def initialize(sql_type = "geometry", geo_type: nil, srid: nil, geographic: false, has_z: false, has_m: false, **_options)
        @sql_type = geographic ? "geography" : sql_type
        parsed_geo_type, parsed_srid, parsed_has_z, parsed_has_m, parsed_geographic = self.class.parse_sql_type(@sql_type)
        @geo_type = self.class.normalize_geo_type(geo_type || parsed_geo_type)
        @srid = srid || parsed_srid
        @has_z = has_z || parsed_has_z
        @has_m = has_m || parsed_has_m
        @geographic = geographic || parsed_geographic
      end

      # sql_type: geometry, geometry(Point), geometry(Point,4326), ...
      #
      # returns [geo_type, srid]
      #   geo_type: geography, geometry, point, line_string, polygon, ...
      #   srid:     1234
      def self.parse_sql_type(sql_type)
        geo_type = nil
        srid = 0
        has_z = false
        has_m = false
        geographic = false

        if sql_type =~ /(geography|geometry)\((.*)\)$/i
          # geometry(Point)
          # geometry(Point,4326)
          geographic = Regexp.last_match(1).casecmp("geography").zero?
          params = Regexp.last_match(2).split(",")
          if params.first =~ /([a-z]+[^zm])(z?)(m?)/i
            geo_type = Regexp.last_match(1)
            has_z = Regexp.last_match(2).casecmp("z").zero?
            has_m = Regexp.last_match(3).casecmp("m").zero?
          end
          srid = Regexp.last_match(1).to_i if params.last =~ /(\d+)/
        elsif sql_type =~ /\A(geography|geometry)\z/i
          geographic = Regexp.last_match(1).casecmp("geography").zero?
          geo_type = Regexp.last_match(1)
        else
          # geometry
          # otherType(a,b)
          geo_type = sql_type
        end
        [geo_type, srid, has_z, has_m, geographic]
      end

      def self.normalize_geo_type(geo_type)
        case geo_type.to_s.underscore.delete("_")
        when "geometrycollection"
          "geometry_collection"
        when "linestring"
          "line_string"
        when "multilinestring"
          "multi_line_string"
        when "multipoint"
          "multi_point"
        when "multipolygon"
          "multi_polygon"
        else
          geo_type.to_s.underscore.presence
        end
      end

      def spatial_factory
        @spatial_factories ||= {}

        @spatial_factories[@srid] ||=
          RGeo::ActiveRecord::SpatialFactoryStore.instance.factory(
            geo_type: @geo_type,
            has_m: @has_m,
            has_z: @has_z,
            sql_type: @geographic ? "geography" : "geometry",
            srid: @srid
          )
      end

      def klass
        type == :geometry ? RGeo::Feature::Geometry : super
      end

      def spatial?
        true
      end

      def type
        :geometry
      end

      # support setting an RGeo object or a WKT string
      def serialize(value)
        return if value.nil?

        geo_value = cast_value(value)
        if geo_value && !@geographic && @srid.to_i.zero? && geo_value.srid != @srid
          geo_value = RGeo::Feature.cast(geo_value, factory: spatial_factory, project: true)
        end

        # TODO: - only valid types should be allowed
        # e.g. linestring is not valid for point column
        raise "maybe should raise" unless RGeo::Feature::Geometry.check_type(geo_value)

        geo_value
      end

      private

      def cast_value(value)
        return if value.nil?

        value.is_a?(::String) ? parse_wkt(value) : value
      end

      # convert WKT string into RGeo object
      def parse_wkt(string)
        marker = string[4, 1]
        if ["\x00", "\x01"].include?(marker)
          @srid = string[0, 4].unpack1(marker == "\x01" ? "V" : "N")
          RGeo::WKRep::WKBParser.new(spatial_factory, support_ewkb: true, default_srid: @srid).parse(string[4..])
        elsif string.match?(/\A[0-9a-fA-F]+\z/)
          original_srid = @srid
          parser = RGeo::WKRep::WKBParser.new(spatial_factory, support_ewkb: true, default_srid: @srid)

          begin
            return parser.parse([string].pack("H*"))
          rescue RGeo::Error::ParseError, RGeo::Error::InvalidGeometry
            @srid = original_srid
          end

          if string[0, 10] =~ /[0-9a-fA-F]{8}0[01]/
            @srid = string[0, 8].to_i(16)
            @srid = [@srid].pack("V").unpack1("N") if string[9, 1] == "1"
            parser = RGeo::WKRep::WKBParser.new(spatial_factory, support_ewkb: true, default_srid: @srid)
            return parser.parse([string[8..]].pack("H*"))
          end

          parser.parse([string].pack("H*"))
        else
          string, srid = Arel::Visitors::Mysql2Rgeo.parse_node(string)
          @srid = srid.zero? ? @srid : srid
          RGeo::WKRep::WKTParser.new(spatial_factory, support_ewkt: true, default_srid: @srid).parse(string)
        end
      rescue RGeo::Error::ParseError, RGeo::Error::InvalidGeometry
        nil
      end
    end
  end
end
