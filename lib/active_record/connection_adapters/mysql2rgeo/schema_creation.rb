# frozen_string_literal: true

module ActiveRecord
  module ConnectionAdapters
    module Mysql2Rgeo
      class SchemaCreation < MySQL::SchemaCreation # :nodoc:
        private

        def add_column_options!(sql, options)
          if options[:srid]
            sql << if @conn.database_version >= "8.0.0"
                     " SRID #{options[:srid]} "
                   else
                    " /*!50705 SRID #{options[:srid]} */ "
                   end
          end

          super
        end
      end
    end
  end
end
