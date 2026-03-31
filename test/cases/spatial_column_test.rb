# frozen_string_literal: true

require_relative "../test_helper"

module Mysql2Rgeo
  class SpatialColumnTest < ActiveSupport::TestCase
    # ------------------------------------------------------------------
    # encode_with / init_with  –  YAML round-trip
    # ------------------------------------------------------------------

    def test_yaml_round_trip_geometry_point_with_srid
      col = build_spatial_column(
        "latlon",
        sql_type: "geometry(Point,4326)",
        type: :geometry,
        spatial: { type: "Point", srid: 4326, has_z: false, has_m: false }
      )
      restored = yaml_round_trip(col)

      assert_equal col.geographic,     restored.geographic
      assert_equal col.geometric_type, restored.geometric_type
      assert_equal col.has_z,          restored.has_z
      assert_equal col.has_m,          restored.has_m
      assert_equal col.srid,           restored.srid
      assert_equal col.limit,          restored.limit

      # Verify specific expected values
      assert_equal false,                   restored.geographic
      assert_equal RGeo::Feature::Point,    restored.geometric_type
      assert_equal false,                   restored.has_z
      assert_equal false,                   restored.has_m
      assert_equal 4326,                    restored.srid
      assert_equal({ srid: 4326, type: "st_point" }, restored.limit)
    end

    def test_yaml_round_trip_geography_point
      col = build_spatial_column(
        "latlon",
        sql_type: "geography(Point,4326)",
        type: :geography,
        spatial: { type: "Point", srid: 4326, has_z: false, has_m: false }
      )
      restored = yaml_round_trip(col)

      assert_equal true,                    restored.geographic
      assert_equal RGeo::Feature::Point,    restored.geometric_type
      assert_equal false,                   restored.has_z
      assert_equal false,                   restored.has_m
      assert_equal 4326,                    restored.srid
      assert_equal({ srid: 4326, type: "st_point", geographic: true }, restored.limit)
    end

    def test_yaml_round_trip_geometry_with_z
      col = build_spatial_column(
        "latlon",
        sql_type: "geometry(PointZ,3509)",
        type: :geometry,
        spatial: { type: "Point", srid: 3509, has_z: true, has_m: false }
      )
      restored = yaml_round_trip(col)

      assert_equal false,                   restored.geographic
      assert_equal RGeo::Feature::Point,    restored.geometric_type
      assert_equal true,                    restored.has_z
      assert_equal false,                   restored.has_m
      assert_equal 3509,                    restored.srid
      assert_equal({ srid: 3509, type: "st_point", has_z: true }, restored.limit)
    end

    def test_yaml_round_trip_geometry_with_m
      col = build_spatial_column(
        "region",
        sql_type: "geometry(PolygonM,#{TEST_GEOMETRIC_SRID})",
        type: :geometry,
        spatial: { type: "Polygon", srid: TEST_GEOMETRIC_SRID, has_z: false, has_m: true }
      )
      restored = yaml_round_trip(col)

      assert_equal false,                     restored.geographic
      assert_equal RGeo::Feature::Polygon,    restored.geometric_type
      assert_equal false,                     restored.has_z
      assert_equal true,                      restored.has_m
      assert_equal TEST_GEOMETRIC_SRID,       restored.srid
      assert_equal({ srid: TEST_GEOMETRIC_SRID, type: "st_polygon", has_m: true }, restored.limit)
    end

    def test_yaml_round_trip_geometry_with_z_and_m
      col = build_spatial_column(
        "geom",
        sql_type: "geometry(GeometryZM,4326)",
        type: :geometry,
        spatial: { type: "Geometry", srid: 4326, has_z: true, has_m: true }
      )
      restored = yaml_round_trip(col)

      assert_equal false,                     restored.geographic
      assert_equal RGeo::Feature::Geometry,   restored.geometric_type
      assert_equal true,                      restored.has_z
      assert_equal true,                      restored.has_m
      assert_equal 4326,                      restored.srid
      assert_equal({ srid: 4326, type: "geometry", has_z: true, has_m: true }, restored.limit)
    end

    def test_yaml_round_trip_simple_geometry_no_srid
      col = build_spatial_column(
        "latlon",
        sql_type: "geometry",
        type: :geometry,
        spatial: { type: "Geometry", srid: 0, has_z: false, has_m: false }
      )
      restored = yaml_round_trip(col)

      assert_equal false,                       restored.geographic
      assert_equal RGeo::Feature::Geometry,     restored.geometric_type
      assert_equal false,                       restored.has_z
      assert_equal false,                       restored.has_m
      assert_equal 0,                           restored.srid
      assert_equal col.limit,                   restored.limit
    end

    def test_yaml_round_trip_preserves_spatial_predicate
      col = build_spatial_column(
        "latlon",
        sql_type: "geometry(Point,4326)",
        type: :geometry,
        spatial: { type: "Point", srid: 4326, has_z: false, has_m: false }
      )
      restored = yaml_round_trip(col)

      assert_equal col.spatial?, restored.spatial?
      assert restored.spatial?
    end

    # ------------------------------------------------------------------
    # ==  /  eql?  –  Equality
    # ------------------------------------------------------------------

    def test_equality_after_yaml_round_trip
      col = build_spatial_column(
        "latlon",
        sql_type: "geometry(Point,4326)",
        type: :geometry,
        spatial: { type: "Point", srid: 4326, has_z: false, has_m: false }
      )
      restored = yaml_round_trip(col)

      assert_equal col, restored
      assert col.eql?(restored)
    end

    def test_equality_after_yaml_round_trip_geography
      col = build_spatial_column(
        "latlon",
        sql_type: "geography(Point,4326)",
        type: :geography,
        spatial: { type: "Point", srid: 4326, has_z: false, has_m: false }
      )
      restored = yaml_round_trip(col)

      assert_equal col, restored
      assert col.eql?(restored)
    end

    def test_equality_after_yaml_round_trip_with_z_and_m
      col = build_spatial_column(
        "region",
        sql_type: "geometry(PolygonZM,#{TEST_GEOMETRIC_SRID})",
        type: :geometry,
        spatial: { type: "Polygon", srid: TEST_GEOMETRIC_SRID, has_z: true, has_m: true }
      )
      restored = yaml_round_trip(col)

      assert_equal col, restored
      assert col.eql?(restored)
    end

    def test_inequality_different_srid
      col1 = build_spatial_column(
        "geom",
        sql_type: "geometry(Geometry,4326)",
        type: :geometry,
        spatial: { type: "Geometry", srid: 4326, has_z: false, has_m: false }
      )
      col2 = build_spatial_column(
        "geom",
        sql_type: "geometry(Geometry,#{TEST_GEOMETRIC_SRID})",
        type: :geometry,
        spatial: { type: "Geometry", srid: TEST_GEOMETRIC_SRID, has_z: false, has_m: false }
      )

      refute_equal col1, col2
    end

    def test_inequality_geographic_vs_geometry
      col_geom = build_spatial_column(
        "geom",
        sql_type: "geometry(Point,4326)",
        type: :geometry,
        spatial: { type: "Point", srid: 4326, has_z: false, has_m: false }
      )
      col_geog = build_spatial_column(
        "geom",
        sql_type: "geography(Point,4326)",
        type: :geography,
        spatial: { type: "Point", srid: 4326, has_z: false, has_m: false }
      )

      refute_equal col_geom, col_geog
    end

    def test_inequality_different_has_z
      col1 = build_spatial_column(
        "geom",
        sql_type: "geometry(Point,4326)",
        type: :geometry,
        spatial: { type: "Point", srid: 4326, has_z: false, has_m: false }
      )
      col2 = build_spatial_column(
        "geom",
        sql_type: "geometry(PointZ,4326)",
        type: :geometry,
        spatial: { type: "Point", srid: 4326, has_z: true, has_m: false }
      )

      refute_equal col1, col2
    end

    def test_inequality_different_has_m
      col1 = build_spatial_column(
        "geom",
        sql_type: "geometry(Point,4326)",
        type: :geometry,
        spatial: { type: "Point", srid: 4326, has_z: false, has_m: false }
      )
      col2 = build_spatial_column(
        "geom",
        sql_type: "geometry(PointM,4326)",
        type: :geometry,
        spatial: { type: "Point", srid: 4326, has_z: false, has_m: true }
      )

      refute_equal col1, col2
    end

    def test_inequality_different_geometric_type
      col1 = build_spatial_column(
        "geom",
        sql_type: "geometry(Point,4326)",
        type: :geometry,
        spatial: { type: "Point", srid: 4326, has_z: false, has_m: false }
      )
      col2 = build_spatial_column(
        "geom",
        sql_type: "geometry(Polygon,4326)",
        type: :geometry,
        spatial: { type: "Polygon", srid: 4326, has_z: false, has_m: false }
      )

      refute_equal col1, col2
    end

    def test_inequality_with_non_spatial_column
      spatial_col = build_spatial_column(
        "latlon",
        sql_type: "geometry(Point,4326)",
        type: :geometry,
        spatial: { type: "Point", srid: 4326, has_z: false, has_m: false }
      )
      # A regular MySQL column
      type_metadata = ActiveRecord::ConnectionAdapters::SqlTypeMetadata.new(
        sql_type: "varchar(255)",
        type: :string,
        limit: 255
      )
      mysql_metadata = ActiveRecord::ConnectionAdapters::MySQL::TypeMetadata.new(type_metadata)
      string_col = ActiveRecord::ConnectionAdapters::MySQL::Column.new("name", nil, mysql_metadata, true)

      refute_equal spatial_col, string_col
    end

    # ------------------------------------------------------------------
    # hash  –  Consistent with equality
    # ------------------------------------------------------------------

    def test_hash_equal_columns_have_same_hash
      col = build_spatial_column(
        "latlon",
        sql_type: "geometry(Point,4326)",
        type: :geometry,
        spatial: { type: "Point", srid: 4326, has_z: false, has_m: false }
      )
      restored = yaml_round_trip(col)

      assert_equal col.hash, restored.hash
    end

    def test_hash_equal_columns_have_same_hash_geography
      col = build_spatial_column(
        "latlon",
        sql_type: "geography(Point,4326)",
        type: :geography,
        spatial: { type: "Point", srid: 4326, has_z: false, has_m: false }
      )
      restored = yaml_round_trip(col)

      assert_equal col.hash, restored.hash
    end

    def test_hash_equal_columns_have_same_hash_with_z_m
      col = build_spatial_column(
        "region",
        sql_type: "geometry(PolygonZM,#{TEST_GEOMETRIC_SRID})",
        type: :geometry,
        spatial: { type: "Polygon", srid: TEST_GEOMETRIC_SRID, has_z: true, has_m: true }
      )
      restored = yaml_round_trip(col)

      assert_equal col.hash, restored.hash
    end

    def test_hash_different_columns_likely_differ
      col_geom = build_spatial_column(
        "geom",
        sql_type: "geometry(Point,4326)",
        type: :geometry,
        spatial: { type: "Point", srid: 4326, has_z: false, has_m: false }
      )
      col_geog = build_spatial_column(
        "geom",
        sql_type: "geography(Point,4326)",
        type: :geography,
        spatial: { type: "Point", srid: 4326, has_z: false, has_m: false }
      )

      # While hash collisions are theoretically possible, these should differ
      refute_equal col_geom.hash, col_geog.hash
    end

    def test_columns_usable_as_hash_keys
      col = build_spatial_column(
        "latlon",
        sql_type: "geometry(Point,4326)",
        type: :geometry,
        spatial: { type: "Point", srid: 4326, has_z: false, has_m: false }
      )
      restored = yaml_round_trip(col)

      hash_map = { col => "original" }
      assert_equal "original", hash_map[restored]
    end

    # ------------------------------------------------------------------
    # encode_with covers all attributes
    # ------------------------------------------------------------------

    def test_encode_with_includes_all_spatial_attributes
      col = build_spatial_column(
        "latlon",
        sql_type: "geography(Point,4326)",
        type: :geography,
        spatial: { type: "Point", srid: 4326, has_z: false, has_m: false }
      )
      coder = {}
      col.encode_with(coder)

      assert_equal true,                  coder["geographic"]
      assert_equal RGeo::Feature::Point,  coder["geometric_type"]
      assert_equal false,                 coder["has_m"]
      assert_equal false,                 coder["has_z"]
      assert_equal 4326,                  coder["srid"]
      assert_equal({ srid: 4326, type: "st_point", geographic: true }, coder["limit"])
    end

    def test_encode_with_geometry_has_z_has_m
      col = build_spatial_column(
        "region",
        sql_type: "geometry(PolygonZM,#{TEST_GEOMETRIC_SRID})",
        type: :geometry,
        spatial: { type: "Polygon", srid: TEST_GEOMETRIC_SRID, has_z: true, has_m: true }
      )
      coder = {}
      col.encode_with(coder)

      assert_equal false,                   coder["geographic"]
      assert_equal RGeo::Feature::Polygon,  coder["geometric_type"]
      assert_equal true,                    coder["has_m"]
      assert_equal true,                    coder["has_z"]
      assert_equal TEST_GEOMETRIC_SRID,     coder["srid"]
      assert_equal({ srid: TEST_GEOMETRIC_SRID, type: "st_polygon", has_z: true, has_m: true }, coder["limit"])
    end

    def test_encode_with_simple_geometry
      col = build_spatial_column(
        "geom",
        sql_type: "geometry",
        type: :geometry,
        spatial: { type: "Geometry", srid: 0, has_z: false, has_m: false }
      )
      coder = {}
      col.encode_with(coder)

      assert_equal false,                     coder["geographic"]
      assert_equal RGeo::Feature::Geometry,   coder["geometric_type"]
      assert_equal false,                     coder["has_m"]
      assert_equal false,                     coder["has_z"]
      assert_equal 0,                         coder["srid"]
    end

    # ------------------------------------------------------------------
    # init_with restores attributes correctly
    # ------------------------------------------------------------------

    def test_init_with_restores_geographic
      col = build_spatial_column(
        "latlon",
        sql_type: "geography(Point,4326)",
        type: :geography,
        spatial: { type: "Point", srid: 4326, has_z: false, has_m: false }
      )

      assert_equal true, col.geographic
      restored = yaml_round_trip(col)
      assert_equal true, restored.geographic
    end

    def test_init_with_restores_geometric_type
      col = build_spatial_column(
        "latlon",
        sql_type: "geometry(LineString,4326)",
        type: :geometry,
        spatial: { type: "LineString", srid: 4326, has_z: false, has_m: false }
      )

      assert_equal RGeo::Feature::LineString, col.geometric_type
      restored = yaml_round_trip(col)
      assert_equal RGeo::Feature::LineString, restored.geometric_type
    end

    def test_init_with_restores_has_z
      col = build_spatial_column(
        "latlon",
        sql_type: "geometry(PointZ,4326)",
        type: :geometry,
        spatial: { type: "Point", srid: 4326, has_z: true, has_m: false }
      )

      assert_equal true, col.has_z
      restored = yaml_round_trip(col)
      assert_equal true, restored.has_z
    end

    def test_init_with_restores_has_m
      col = build_spatial_column(
        "latlon",
        sql_type: "geometry(PointM,4326)",
        type: :geometry,
        spatial: { type: "Point", srid: 4326, has_z: false, has_m: true }
      )

      assert_equal true, col.has_m
      restored = yaml_round_trip(col)
      assert_equal true, restored.has_m
    end

    def test_init_with_restores_srid
      col = build_spatial_column(
        "latlon",
        sql_type: "geometry(Point,3857)",
        type: :geometry,
        spatial: { type: "Point", srid: 3857, has_z: false, has_m: false }
      )

      assert_equal 3857, col.srid
      restored = yaml_round_trip(col)
      assert_equal 3857, restored.srid
    end

    def test_init_with_restores_limit
      col = build_spatial_column(
        "latlon",
        sql_type: "geography(Point,4326)",
        type: :geography,
        spatial: { type: "Point", srid: 4326, has_z: false, has_m: false }
      )

      expected_limit = { srid: 4326, type: "st_point", geographic: true }
      assert_equal expected_limit, col.limit
      restored = yaml_round_trip(col)
      assert_equal expected_limit, restored.limit
    end

    private

    def build_spatial_column(name, sql_type:, type:, spatial:)
      base_metadata = ActiveRecord::ConnectionAdapters::SqlTypeMetadata.new(
        sql_type: sql_type,
        type: type
      )
      mysql_metadata = ActiveRecord::ConnectionAdapters::MySQL::TypeMetadata.new(base_metadata)

      ActiveRecord::ConnectionAdapters::Mysql2Rgeo::SpatialColumn.new(
        name,
        nil,        # default
        mysql_metadata,
        true,       # null
        nil,        # default_function
        spatial: spatial
      )
    end

    def yaml_round_trip(column)
      yaml_str = YAML.dump(column)
      YAML.unsafe_load(yaml_str)
    end
  end
end
