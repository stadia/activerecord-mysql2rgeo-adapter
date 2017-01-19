module ActiveRecord  # :nodoc:
  module ConnectionAdapters  # :nodoc:
    module Mysql2Rgeo  # :nodoc:
      def self.initial_setup
        ::ActiveRecord::SchemaDumper.ignore_tables |= %w(
          geography_columns
          geometry_columns
          layer
          raster_columns
          raster_overviews
          spatial_ref_sys
          topology
        )
      end
    end
  end
end
