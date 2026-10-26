# frozen_string_literal: true

require_relative "../test_helper"

module Mysql2Rgeo
  class SridZeroTest < ActiveSupport::TestCase
    POLYGON_WKT = "POLYGON ((0.0 0.0, 0.0 10.0, 10.0 10.0, 10.0 0.0, 0.0 0.0))"
    MULTI_POLYGON_WKT = "MULTIPOLYGON (((0.0 0.0, 0.0 10.0, 10.0 10.0, 10.0 0.0, 0.0 0.0)), " \
                        "((20.0 20.0, 20.0 30.0, 30.0 30.0, 30.0 20.0, 20.0 20.0)))"
    MULTI_LINE_STRING_WKT = "MULTILINESTRING ((0.0 0.0, 1.0 1.0, 2.0 2.0), (3.0 3.0, 4.0 4.0))"
    MULTI_POINT_WKT = "MULTIPOINT ((1.0 2.0), (3.0 4.0))"

    def teardown
      reset_spatial_store
    end

    def test_create_multi_polygon_srid_zero
      create_column("boundary", :multi_polygon, srid: 0)

      col = klass.columns.last
      assert_equal RGeo::Feature::MultiPolygon, col.geometric_type
      assert_equal 0, col.srid
      assert_equal true, col.spatial?
      assert_equal false, col.geographic?
    end

    def test_multi_polygon_srid_zero_round_trip
      create_column("boundary", :multi_polygon, srid: 0)

      rec = klass.new
      rec.boundary = MULTI_POLYGON_WKT
      assert rec.save

      rec = klass.find(rec.id)
      assert RGeo::Feature::MultiPolygon.check_type(rec.boundary)
      assert_wkt MULTI_POLYGON_WKT, rec.boundary
      assert_equal 0, rec.boundary.srid
    end

    # A generic geometry column holds whatever it is given, so the value's own type is what has to
    # survive the round trip rather than the column's declared type.
    def test_generic_geometry_srid_zero_holds_a_polygon
      create_column("geom", :geometry, srid: 0)

      rec = klass.new
      rec.geom = POLYGON_WKT
      assert rec.save

      rec = klass.find(rec.id)
      assert RGeo::Feature::Polygon.check_type(rec.geom)
      assert_wkt POLYGON_WKT, rec.geom
      assert_equal 0, rec.geom.srid
    end

    def test_generic_geometry_srid_zero_holds_a_multi_polygon
      create_column("geom", :geometry, srid: 0)

      rec = klass.new
      rec.geom = MULTI_POLYGON_WKT
      assert rec.save

      rec = klass.find(rec.id)
      assert RGeo::Feature::MultiPolygon.check_type(rec.geom)
      assert_wkt MULTI_POLYGON_WKT, rec.geom
    end

    def test_multi_line_string_srid_zero_round_trip
      create_column("paths", :multi_line_string, srid: 0)

      rec = klass.new
      rec.paths = MULTI_LINE_STRING_WKT
      assert rec.save

      rec = klass.find(rec.id)
      assert RGeo::Feature::MultiLineString.check_type(rec.paths)
      assert_wkt MULTI_LINE_STRING_WKT, rec.paths
      assert_equal 0, rec.paths.srid
    end

    def test_multi_point_srid_zero_round_trip
      create_column("stops", :multi_point, srid: 0)

      rec = klass.new
      rec.stops = MULTI_POINT_WKT
      assert rec.save

      rec = klass.find(rec.id)
      assert RGeo::Feature::MultiPoint.check_type(rec.stops)
      assert_equal 0, rec.stops.srid
    end

    def test_srid_zero_column_accepts_an_rgeo_object
      create_column("boundary", :multi_polygon, srid: 0)
      cartesian = factory(srid: 0)

      ring = cartesian.linear_ring(
        [cartesian.point(0, 0), cartesian.point(0, 1), cartesian.point(1, 1),
         cartesian.point(1, 0), cartesian.point(0, 0)]
      )
      areas = cartesian.multi_polygon([cartesian.polygon(ring)])

      rec = klass.new
      rec.boundary = areas
      assert rec.save

      rec = klass.find(rec.id)
      assert_equal areas, rec.boundary
      assert_equal 0, rec.boundary.srid
    end

    def test_srid_zero_and_srid_4326_columns_coexist
      klass.connection.create_table(:spatial_models, force: true) do |t|
        t.column "boundary_zero", :multi_polygon, srid: 0
        t.column "boundary_4326", :multi_polygon, srid: 4326
      end
      klass.reset_column_information

      zero, wgs84 = klass.columns.last(2)
      assert_equal 0, zero.srid
      assert_equal 4326, wgs84.srid

      rec = klass.new
      rec.boundary_zero = MULTI_POLYGON_WKT
      rec.boundary_4326 = MULTI_POLYGON_WKT
      assert rec.save

      rec = klass.find(rec.id)
      assert_equal 0, rec.boundary_zero.srid
      assert_equal 4326, rec.boundary_4326.srid
    end

    def test_srid_zero_column_survives_schema_dump
      create_column("boundary", :multi_polygon, srid: 0)

      dump = StringIO.new
      ActiveRecord::SchemaDumper.dump(klass.connection, dump)

      line = dump.string.lines.grep(/"boundary"/).first
      assert line, "boundary column missing from the schema dump"
      assert_match(/t\.geometry/, line)
      assert_match(/(:type\s*=>|type:)\s*"multi_polygon"/, line)
      assert_match(/(:srid\s*=>|srid:)\s*0/, line)
    end

    private

    # WKT number formatting depends on the factory (GEOS writes "0", others "0.0"), so compare geometries.
    def assert_wkt(expected, geom)
      assert geom.rep_equals?(geom.factory.parse_wkt(expected)), "Expected #{expected}, got #{geom}"
    end

    def klass
      SpatialModel
    end

    def create_column(name, type, srid:)
      klass.connection.create_table(:spatial_models, force: true) do |t|
        t.column name, type, srid: srid
      end
      klass.reset_column_information
    end
  end
end
