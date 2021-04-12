# frozen_string_literal: true

require "test_helper"

class DDLTest < ActiveSupport::TestCase
  def test_spatial_column_options
    [
      :geometry,
      :geometrycollection,
      :linestring,
      :multilinestring,
      :multipoint,
      :multipolygon,
      :point,
      :polygon,
    ].each do |type|
      assert ActiveRecord::ConnectionAdapters::Mysql2RgeoAdapter.spatial_column_options(type), type
    end
  end

  def test_type_to_sql
    adapter = SpatialModel.connection
    assert_equal "GEOMETRY", adapter.type_to_sql(:geometry, limit: "point,4326")
  end

  def test_create_simple_geometry
    klass.connection.create_table(:spatial_models, force: true) do |t|
      t.column "latlon", :geometry
    end
    klass.reset_column_information
    col = klass.columns.last
    assert_equal RGeo::Feature::Geometry, col.geometric_type
    assert_equal true, col.spatial?
    assert_equal false, col.geographic?
    assert_equal 0, col.srid
    klass.connection.drop_table(:spatial_models)
  end

  def test_create_simple_geography
    klass.connection.create_table(:spatial_models, force: true) do |t|
      t.column "latlon", :geometry, geographic: true
    end
    klass.reset_column_information
    col = klass.columns.last
    assert_equal RGeo::Feature::Geometry, col.geometric_type
    assert_equal true, col.spatial?
    assert_equal false, col.geographic?
    assert_equal 0, col.srid
  end

  def test_create_point_geometry
    klass.connection.create_table(:spatial_models, force: true) do |t|
      t.column "latlon", :point
    end
    klass.reset_column_information
    assert_equal RGeo::Feature::Point, klass.columns.last.geometric_type
  end

  def test_create_geometry_with_index
    klass.connection.create_table(:spatial_models, force: true) do |t|
      t.column "latlon", :geometry, null: false
    end
    klass.connection.change_table(:spatial_models) do |t|
      t.index([:latlon], type: :spatial)
    end
    klass.reset_column_information
  end

  def test_add_geometry_column
    klass.connection.create_table(:spatial_models, force: true) do |t|
      t.column("latlon", :geometry)
    end
    klass.connection.change_table(:spatial_models) do |t|
      t.column("geom2", :point, srid: 4326)
      t.column("name", :string)
    end
    klass.reset_column_information
    columns = klass.columns
    assert_equal RGeo::Feature::Geometry, columns[-3].geometric_type
    assert_equal 0, columns[-3].srid
    assert_equal true, columns[-3].spatial?
    assert_equal RGeo::Feature::Point, columns[-2].geometric_type
    assert_equal 0, columns[-2].srid
    assert_equal false, columns[-2].geographic?
    assert_equal true, columns[-2].spatial?
    assert_nil columns[-1].geometric_type
    assert_equal false, columns[-1].spatial?
  end

  def test_add_geometry_column_null_false
    klass.connection.create_table(:spatial_models, force: true) do |t|
      t.column("latlon_null", :geometry, null: false)
      t.column("latlon", :geometry)
    end
    klass.reset_column_information
    null_false_column = klass.columns[1]
    null_true_column = klass.columns[2]

    refute null_false_column.null, "Column should be null: false"
    assert null_true_column.null, "Column should be null: true"
  end

  def test_add_geography_column
    klass.connection.create_table(:spatial_models, force: true) do |t|
      t.column("latlon", :geometry)
    end
    klass.connection.change_table(:spatial_models) do |t|
      t.point("geom3", srid: 4326, geographic: true)
      t.column("geom2", :point, srid: 4326, geographic: true)
      t.column("name", :string)
    end
    klass.reset_column_information
    cols = klass.columns
    # latlon
    assert_equal RGeo::Feature::Geometry, cols[-4].geometric_type
    assert_equal 0, cols[-4].srid
    assert_equal true, cols[-4].spatial?
    # geom3
    assert_equal RGeo::Feature::Point, cols[-3].geometric_type
    assert_equal 0, cols[-3].srid
    assert_equal false, cols[-3].geographic?
    assert_equal true, cols[-3].spatial?
    # geom2
    assert_equal RGeo::Feature::Point, cols[-2].geometric_type
    assert_equal 0, cols[-2].srid
    assert_equal false, cols[-2].geographic?
    assert_equal true, cols[-2].spatial?
    # name
    assert_nil cols[-1].geometric_type
    assert_equal false, cols[-1].spatial?
  end

  def test_drop_geometry_column
    klass.connection.create_table(:spatial_models, force: true) do |t|
      t.column("latlon", :geometry)
      t.column("geom2", :point, srid: 4326)
    end
    klass.connection.change_table(:spatial_models) do |t|
      t.remove("geom2")
    end
    klass.reset_column_information
    cols = klass.columns
    assert_equal RGeo::Feature::Geometry, cols[-1].geometric_type
    assert_equal "latlon", cols[-1].name
    assert_equal 0, cols[-1].srid
    assert_equal false, cols[-1].geographic?
  end

  def test_drop_geography_column
    klass.connection.create_table(:spatial_models, force: true) do |t|
      t.column("latlon", :geometry)
      t.column("geom2", :point, srid: 4326, geographic: true)
      t.column("geom3", :point, srid: 4326)
    end
    klass.connection.change_table(:spatial_models) do |t|
      t.remove("geom2")
    end
    klass.reset_column_information
    columns = klass.columns
    assert_equal RGeo::Feature::Point, columns[-1].geometric_type
    assert_equal "geom3", columns[-1].name
    assert_equal false, columns[-1].geographic?
    assert_equal RGeo::Feature::Geometry, columns[-2].geometric_type
    assert_equal "latlon", columns[-2].name
    assert_equal false, columns[-2].geographic?
  end

  def test_create_simple_geometry_using_shortcut
    klass.connection.create_table(:spatial_models, force: true) do |t|
      t.geometry "latlon"
    end
    klass.reset_column_information
    col = klass.columns.last
    assert_equal RGeo::Feature::Geometry, col.geometric_type
    assert_equal false, col.geographic?
    assert_equal 0, col.srid
    klass.connection.drop_table(:spatial_models)
  end

  def test_create_simple_geography_using_shortcut
    klass.connection.create_table(:spatial_models, force: true) do |t|
      t.geometry "latlon", geographic: true
    end
    klass.reset_column_information
    col = klass.columns.last
    assert_equal RGeo::Feature::Geometry, col.geometric_type
    assert_equal false, col.geographic?
    assert_equal 0, col.srid
  end

  def test_create_point_geometry_using_shortcut
    klass.connection.create_table(:spatial_models, force: true) do |t|
      t.point "latlon"
    end
    klass.reset_column_information
    assert_equal RGeo::Feature::Point, klass.columns.last.geometric_type
  end

  def test_create_geometry_using_shortcut_with_srid
    klass.connection.create_table(:spatial_models, force: true) do |t|
      t.geometry "latlon", srid: 4326
    end
    klass.reset_column_information
    col = klass.columns.last
    assert_equal RGeo::Feature::Geometry, col.geometric_type
    assert_equal({ srid: 0, type: "geometry" }, col.limit)
  end

  def test_create_polygon_with_options
    klass.connection.create_table(:spatial_models, force: true) do |t|
      t.column "region", :polygon, has_m: true, srid: 3857
    end
    klass.reset_column_information
    col = klass.columns.last
    assert_equal RGeo::Feature::Polygon, col.geometric_type
    assert_equal false, col.geographic?
    assert_equal false, col.has_z?
    assert_equal false, col.has_m?
    assert_equal 0, col.srid
    assert_equal({ type: "polygon", srid: 0 }, col.limit)
    klass.connection.drop_table(:spatial_models)
  end

  # Ensure that null contraints info is getting captured like the
  # normal adapter.
  def test_null_constraints
    klass.connection.create_table(:spatial_models, force: true) do |t|
      t.column "nulls_allowed", :string, null: true
      t.column "nulls_disallowed", :string, null: false
    end
    klass.reset_column_information
    assert_equal true, klass.columns[-2].null
    assert_equal false, klass.columns[-1].null
  end

  # Ensure column default value works like the Postgres adapter.
  def test_column_defaults
    klass.connection.create_table(:spatial_models, force: true) do |t|
      t.column "sample_integer", :integer, default: -1
    end
    klass.reset_column_information
    assert_equal(-1, klass.new.sample_integer)
  end

  def test_column_types
    klass.connection.create_table(:spatial_models, force: true) do |t|
      t.column "sample_integer", :integer
      t.column "sample_string", :string
      t.column "latlon", :point
    end
    klass.reset_column_information
    assert_equal :integer, klass.columns[-3].type
    assert_equal :string, klass.columns[-2].type
    assert_equal :geometry, klass.columns[-1].type
  end

  def test_reload_dumped_schema
    klass.connection.create_table(:spatial_models, force: true) do |t|
      t.geometry "latlon1", limit: { srid: 4326, type: "point", geographic: true }
    end
    klass.reset_column_information
    col = klass.columns.last
    assert_equal 0, col.srid
  end

  def test_non_spatial_column_limits
    klass.connection.create_table(:spatial_models, force: true) do |t|
      t.string :foo, limit: 123
    end
    klass.reset_column_information
    col = klass.columns.last
    assert_equal 123, col.limit
  end

  def test_column_comments
    klass.connection.create_table(:spatial_models, force: true) do |t|
      t.string :sample_comment, comment: 'Comment test'
    end
    klass.reset_column_information
    col = klass.columns.last
    assert_equal 'Comment test', col.comment
  end

  private

  def klass
    SpatialModel
  end
end
