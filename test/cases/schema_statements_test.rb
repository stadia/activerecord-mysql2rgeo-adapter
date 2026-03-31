# frozen_string_literal: true

require_relative "../test_helper"

module Mysql2Rgeo
  class SchemaStatementsTest < ActiveSupport::TestCase
    def test_initialize_type_map
      SpatialModel.with_connection do |connection|
        connection.connect!
        initialized_types = connection.send(:type_map).keys

        # Keep mysql2rgeo-specific spatial aliases ahead of generic mappings.
        assert_equal initialized_types.first(9), %w[
          geography
          geometry
          geometry_collection
          line_string
          multi_line_string
          multi_point
          multi_polygon
          st_point
          st_polygon
        ]
      end
    end
  end
end
