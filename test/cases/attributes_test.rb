# frozen_string_literal: true

require_relative "../test_helper"

class AttributesTest < ActiveSupport::TestCase
  class SpatialAttributeModel < ActiveRecord::Base
    self.table_name = "spatial_attribute_models"

    attribute :point, :point, srid: 3857
    attribute :polygon, :polygon, srid: 3857
  end

  def setup
    reset_spatial_store
  end

  def test_spatial_attributes
    data = SpatialAttributeModel.new
    data.point = "POINT(0 0)"
    data.polygon = "POLYGON((0 0, 0 1, 1 1, 1 0, 0 0))"

    assert_equal 3857, data.point.srid
    assert_equal 0, data.point.x
    assert_equal 0, data.point.y
    assert_equal 3857, data.polygon.srid
  end
end
