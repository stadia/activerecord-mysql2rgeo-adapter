# frozen_string_literal: true

module ActiveRecord
  module ConnectionAdapters
    module Mysql2Rgeo
      class SchemaCreation < MySQL::SchemaCreation # :nodoc:
        private

          def add_column_options!(sql, options)
            # By default, TIMESTAMP columns are NOT NULL, cannot contain NULL values,
            # and assigning NULL assigns the current timestamp. To permit a TIMESTAMP
            # column to contain NULL, explicitly declare it with the NULL attribute.
            # See https://dev.mysql.com/doc/refman/en/timestamp-initialization.html
            if /\Atimestamp\b/.match?(options[:column].sql_type) && !options[:primary_key]
              sql << " NULL" unless options[:null] == false || options_include_default?(options)
            end

            if options[:srid]
              sql << " /*!80003 SRID #{options[:srid]} */"
            end

            if charset = options[:charset]
              sql << " CHARACTER SET #{charset}"
            end

            if collation = options[:collation]
              sql << " COLLATE #{collation}"
            end

            if as = options[:as]
              sql << " AS (#{as})"
              if options[:stored]
                sql << (mariadb? ? " PERSISTENT" : " STORED")
              end
            end

            add_sql_comment!(super, options[:comment])
          end
      end
    end
  end
end