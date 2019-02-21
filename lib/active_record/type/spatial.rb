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
      # returns [geo_type, srid, has_z, has_m]
      #   geo_type: geography, geometry, point, line_string, polygon, ...
      #   srid:     1234
      def self.parse_sql_type(sql_type)
        geo_type, srid, has_z, has_m = nil, 0, false, false

        if sql_type =~ /(geography|geometry)\((.*)\)$/i
          # geometry(Point,4326)
          params = Regexp.last_match(2).split(",")
          if params.size > 1
            if params.first =~ /([a-z]+[^zm])(z?)(m?)/i
              geo_type = Regexp.last_match(1)
            end
            if params.last =~ /(\d+)/
              srid = Regexp.last_match(1).to_i
            end
          else
            # geometry(Point)
            geo_type = params[0]
          end
        else
          # geometry
          geo_type = sql_type
        end
        [geo_type, srid]
      end

      def klass
        puts type
        type == :geometry ? RGeo::Feature::Geometry : super
      end

      def type
        :geometry
      end

      def spatial?
        true
      end

      def spatial_factory
        @spatial_factory ||=
          RGeo::ActiveRecord::SpatialFactoryStore.instance.factory(
            geo_type: @geo_type,
            sql_type: @sql_type,
            srid: @srid
          )
      end

      # support setting an RGeo object or a WKT string
      def serialize(value)
        return if value.nil?
        geo_value = cast_value(value)

        # TODO - only valid types should be allowed
        # e.g. linestring is not valid for point column
        raise "maybe should raise" unless RGeo::Feature::Geometry.check_type(geo_value)
        geo_value
      end

      private

      def cast_value(value)
        return if value.nil?
        case value
        when ::RGeo::Feature::Geometry
          value
          # RGeo::Feature.cast(value, spatial_factory) rescue nil
        when ::String
          marker = value[4, 1]
          if marker == "\x00" || marker == "\x01"
            srid = value[0, 4].unpack(marker == "\x01" ? "V" : "N").first
            begin
              RGeo::WKRep::WKBParser.new(spatial_factory, support_ewkb: true, default_srid: srid).parse(value[4..-1])
            rescue
              nil
            end
          elsif value[0, 10] =~ /[0-9a-fA-F]{8}0[01]/
            srid = value[0, 8].to_i(16)
            srid = [srid].pack("V").unpack("N").first if value[9, 1] == "1"
            begin
              RGeo::WKRep::WKBParser.new(spatial_factory, support_ewkb: true, default_srid: srid).parse(value[8..-1])
            rescue
              nil
            end
          else
            begin
              RGeo::WKRep::WKTParser.new(spatial_factory, support_ewkt: true, default_srid: @srid).parse(value)
            rescue
              nil
            end
          end
        end
      end
    end
  end
end
