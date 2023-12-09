# frozen_string_literal: true

module ActiveRecord
  module ConnectionAdapters
    module Mysql2Rgeo
      class SchemaCreation < MySQL::SchemaCreation # :nodoc:
        private

          def add_column_options!(sql, options)
            if options[:srid]
              sql << " /*!80003 SRID #{options[:srid]} */"
            end

            super
          end
      end
    end
  end
end
