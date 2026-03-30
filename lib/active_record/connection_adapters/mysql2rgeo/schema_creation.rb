# frozen_string_literal: true

module ActiveRecord
  module ConnectionAdapters
    module Mysql2Rgeo
      class SchemaCreation < MySQL::SchemaCreation # :nodoc:
        private
          def visit_IndexDefinition(o, create = false)
            if o.using&.to_sym == :gist
              sql = create ? ["CREATE SPATIAL INDEX"] : ["SPATIAL INDEX"]
              sql << quote_column_name(o.name)
              sql << "ON #{quote_table_name(o.table)}" if create
              sql << "(#{quoted_columns(o)})"
              return sql.join(" ")
            end

            super
          end

          def add_column_options!(sql, options)
            if options[:srid]
              sql << " /*!80003 SRID #{options[:srid]} */"
              options = options.except(:srid)
            end

            if options_include_default?(options) && spatial_column_definition?(options[:column])
              quoted_default = quote_default_expression(options[:default], options[:column])
              sql << " DEFAULT (#{quoted_default})"
              options = options.except(:default)
            end

            super
          end

          def spatial_column_definition?(column)
            column.respond_to?(:type) && column.type && @conn.class.spatial_column_options(column.type.to_sym)
          end
      end
    end
  end
end
