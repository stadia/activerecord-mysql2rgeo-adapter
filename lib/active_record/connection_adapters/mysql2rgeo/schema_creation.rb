# frozen_string_literal: true

module ActiveRecord
  module ConnectionAdapters
    module Mysql2Rgeo
      class SchemaCreation < MySQL::SchemaCreation # :nodoc:
        delegate :database_version, to: :@conn, private: true

        private

          def add_column_options!(sql, options)
            if options[:srid]
              sql << (database_version > "8.0.0" ? " SRID #{options[:srid]}" : " /*!80003 SRID #{options[:srid]} */")
            end

            super
          end
      end
    end
  end
end
