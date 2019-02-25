# frozen_string_literal: true

require "test_helper"

class BasicTest < ActiveSupport::TestCase
  def test_version
    refute_nil ActiveRecord::ConnectionAdapters::Mysql2Rgeo::VERSION
  end

  def test_mysql2rgeo_available
    assert_equal "Mysql2Rgeo", SpatialModel.connection.adapter_name
  end

  def test_arel_visitor
    visitor = Arel::Visitors::Mysql2Rgeo.new(SpatialModel.connection)
    node = RGeo::ActiveRecord::SpatialConstantNode.new("POINT (1.0 2.0)")
    collector = Arel::Collectors::PlainString.new
    visitor.accept(node, collector)
    assert_equal "ST_GeomFromText('POINT (1.0 2.0)')", collector.value
  end

  def test_set_and_get_point
    create_model
    obj = SpatialModel.new
    assert_nil obj.latlon
    obj.latlon = factory.point(1.0, 2.0)
    assert_equal factory.point(1.0, 2.0), obj.latlon
    assert_equal 0, obj.latlon.srid
  end

  def test_set_and_get_point_from_wkt
    create_model
    obj = SpatialModel.new
    assert_nil obj.latlon
    obj.latlon = "POINT(1 2)"
    assert_equal factory.point(1.0, 2.0), obj.latlon
    assert_equal 0, obj.latlon.srid
  end

  def test_save_and_load_point
    create_model
    obj = SpatialModel.new
    obj.latlon = factory.point(1.0, 2.0)
    obj.save!
    id = obj.id
    obj2 = SpatialModel.find(id)
    assert_equal factory.point(1.0, 2.0), obj2.latlon
    assert_equal 0, obj2.latlon.srid
    # assert_equal true, RGeo::Geos.is_geos?(obj2.latlon)
  end

  def test_save_and_load_geographic_point
    create_model
    obj = SpatialModel.new
    obj.latlon_geo = geographic_factory.point(1.0, 2.0)
    obj.save!
    id = obj.id
    obj2 = SpatialModel.find(id)
    # assert_equal geographic_factory.point(1.0, 2.0), obj2.latlon_geo
    assert_equal 0, obj2.latlon_geo.srid
    # assert_equal false, RGeo::Geos.is_geos?(obj2.latlon_geo)
  end

  def test_save_and_load_point_from_wkt
    create_model
    obj = SpatialModel.new
    obj.latlon = "POINT(1 2)"
    obj.save!
    id = obj.id
    obj2 = SpatialModel.find(id)
    assert_equal factory.point(1.0, 2.0), obj2.latlon
    assert_equal 0, obj2.latlon.srid
  end

  def test_set_point_bad_wkt
    create_model
    obj = SpatialModel.create(latlon: "POINT (x)")
    assert_nil obj.latlon
  end

  def test_set_point_wkt_wrong_type
    create_model
    assert_raises(ActiveRecord::StatementInvalid) do
      SpatialModel.create(latlon: "LINESTRING(1 2, 3 4, 5 6)")
    end
  end

  def test_custom_factory
    klass = SpatialModel
    klass.connection.create_table(:spatial_models, force: true) do |t|
      t.polygon(:area, srid: 4326)
    end
    klass.reset_column_information
    custom_factory = RGeo::Geographic.spherical_factory(buffer_resolution: 8, srid: 4326)
    spatial_factory_store.register(custom_factory, geo_type: "polygon", srid: 4326)
    object = klass.new
    area = custom_factory.point(1, 2).buffer(3)
    object.area = area
    object.save!
    object.reload
    assert_equal area.to_s, object.area.to_s
    spatial_factory_store.clear
  end

  def test_readme_example
    spatial_factory_store.register(
      RGeo::Geographic.spherical_factory, geo_type: "point", sql_type: "geography")

    klass = SpatialModel
    klass.connection.create_table(:spatial_models, force: true) do |t|
      t.column(:shape, :geometry)
      t.linestring(:path, srid: 3785)
      t.point(:latlon, null: false, geographic: true)
    end
    klass.reset_column_information
    assert_includes klass.columns.map(&:name), "shape"
    klass.connection.change_table(:spatial_models) do |t|
      t.index(:latlon, type: :spatial)
    end

    object = klass.new
    object.latlon = "POINT(-122 47)"
    point = object.latlon
    # assert_equal 47, point.latitude
    object.shape = point
    assert_equal true, RGeo::Geos.is_geos?(object.shape)

    spatial_factory_store.clear
  end

  def test_point_to_json
    create_model
    obj = SpatialModel.new
    assert_match(/"latlon":null/, obj.to_json)
    obj.latlon = factory.point(1.0, 2.0)
    assert_match(/"latlon":"POINT\s\(1\.0\s2\.0\)"/, obj.to_json)
  end

  def test_custom_column
    create_model
    rec = SpatialModel.new
    rec.latlon = "POINT(0 0)"
    rec.save
    refute_nil SpatialModel.select("CURRENT_TIMESTAMP as ts").first.ts
  end

  def test_multi_polygon_column
    SpatialModel.connection.create_table(:spatial_models, force: true) do |t|
      t.column "m_poly", :multi_polygon
    end
    SpatialModel.reset_column_information
    rec = SpatialModel.new
    wkt = "MULTIPOLYGON (((-73.97210545302842 40.782991711401195, " \
          "-73.97228912063449 40.78274091498208, " \
          "-73.97235226842568 40.78276752827304, " \
          "-73.97216860098405 40.783018324791776, " \
          "-73.97210545302842 40.782991711401195)))"
    rec.m_poly = wkt
    assert rec.save
    rec = SpatialModel.find(rec.id) # force reload
    assert rec.m_poly.is_a?(RGeo::Geos::CAPIMultiPolygonImpl)
    assert_equal wkt, rec.m_poly.to_s
  end

  private

  def create_model
    SpatialModel.connection.create_table(:spatial_models, force: true) do |t|
      t.column "latlon", :point, srid: 3785
      t.column "latlon_geo", :point, srid: 4326, geographic: true
    end
    SpatialModel.reset_column_information
  end

  def spatial_factory_store
    RGeo::ActiveRecord::SpatialFactoryStore.instance
  end
end
