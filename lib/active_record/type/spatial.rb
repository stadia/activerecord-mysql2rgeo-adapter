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
      #   has_z:    false
      #   has_m:    false
      def self.parse_sql_type(sql_type)
        geo_type, srid, has_z, has_m = nil, 0, false, false

        if sql_type =~ /[geography,geometry]\((.*)\)$/i
          # geometry(Point,4326)
          params = Regexp.last_match(1).split(",")
          if params.size > 1
            if params.first =~ /([a-z]+[^zm])(z?)(m?)/i
              has_z = !Regexp.last_match(2).empty?
              has_m = !Regexp.last_match(3).empty?
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
        [geo_type, srid, has_z, has_m]
      end

      def klass
        type == :spatial ? RGeo::Feature::Geometry : super
      end

      def type
        :spatial
      end

      def spatial?
        type == :spatial
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
        geo_value
        # TODO: - only valid types should be allowed
        # e.g. linestring is not valid for point column
        # raise "maybe should raise" unless RGeo::Feature::Geometry.check_type(geo_value)
        # RGeo::WKRep::WKBGenerator.new(hex_format: true, type_format: :ewkb, emit_ewkb_srid: true).generate(geo_value)
      end

      private

      # Convenience method for types which do not need separate type casting
      # behavior for user and database inputs. Called by Value#cast for
      # values except +nil+.
      def cast_value(value) # :doc:
        return if value.nil?
        value.class === "String" ? parse_wkt(value) : parse_wkt(value.to_s)
      end

      # convert WKT string into RGeo object
      def parse_wkt(string)
        wkt_parser(string).parse(string)
      rescue RGeo::Error::ParseError
        nil
      end

      def binary_string?(string)
        string[0] == "\x00" || string[0] == "\x01" || string[0, 4] =~ /[0-9a-fA-F]{4}/
      end

      def wkt_parser(string)
        if binary_string?(string)
          RGeo::WKRep::WKBParser.new(spatial_factory, support_ewkb: true, default_srid: @srid)
        else
          RGeo::WKRep::WKTParser.new(spatial_factory, support_ewkt: true, default_srid: @srid)
        end
      end
    end
  end
end
