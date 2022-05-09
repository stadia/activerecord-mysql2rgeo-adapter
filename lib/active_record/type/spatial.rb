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
      def initialize(sql_type = "geometry")
        @sql_type = sql_type
        @geo_type, @srid = self.class.parse_sql_type(sql_type)
      end

      # sql_type: geometry, geometry(Point), geometry(Point,4326), ...
      #
      # returns [geo_type, srid]
      #   geo_type: geography, geometry, point, line_string, polygon, ...
      #   srid:     1234
      def self.parse_sql_type(sql_type)
        geo_type, srid = nil, 0, false, false
        if sql_type =~ /(geography|geometry)\((.*)\)$/i
          # geometry(Point)
          # geometry(Point,4326)
          params = Regexp.last_match(2).split(",")
          if params.first =~ /([a-z]+[^zm])(z?)(m?)/i
            geo_type = Regexp.last_match(1)
          end
          if params.last =~ /(\d+)/
            srid = Regexp.last_match(1).to_i
          end
        else
          # geometry
          # otherType(a,b)
          geo_type = sql_type
        end
        [geo_type, srid]
      end

      def spatial_factory
        @spatial_factories ||= {}

        @spatial_factories[@srid] ||=
          RGeo::ActiveRecord::SpatialFactoryStore.instance.factory(
            geo_type: @geo_type,
            sql_type: @sql_type,
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

        # TODO: - only valid types should be allowed
        # e.g. linestring is not valid for point column
        raise "maybe should raise" unless RGeo::Feature::Geometry.check_type(geo_value)

        geo_value
      end

      private

      def cast_value(value)
        return if value.nil?

        ::String === value ? parse_wkt(value) : value
      end

      # convert WKT string into RGeo object
      def parse_wkt(string)
        marker = string[4, 1]
        if ["\x00", "\x01"].include?(marker)
          @srid = string[0, 4].unpack1(marker == "\x01" ? "V" : "N")
          RGeo::WKRep::WKBParser.new(spatial_factory, support_ewkb: true, default_srid: @srid).parse(string[4..-1])
        elsif string[0, 10] =~ /[0-9a-fA-F]{8}0[01]/
          @srid = string[0, 8].to_i(16)
          @srid = [@srid].pack("V").unpack("N").first if string[9, 1] == "1"
          RGeo::WKRep::WKBParser.new(spatial_factory, support_ewkb: true, default_srid: srid).parse(string[8..-1])
        else
          string, @srid = Arel::Visitors::Mysql2Rgeo.parse_node(string)
          RGeo::WKRep::WKTParser.new(spatial_factory, support_ewkt: true, default_srid: @srid).parse(string)
        end
      rescue RGeo::Error::ParseError, RGeo::Error::InvalidGeometry
        nil
      end
    end
  end
end
