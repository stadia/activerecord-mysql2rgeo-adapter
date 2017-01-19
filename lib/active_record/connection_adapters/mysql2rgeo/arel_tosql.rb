module Arel  # :nodoc:
  module Visitors  # :nodoc:
    # Different super-class under JRuby JDBC adapter.
    # PostGISSuperclass = if defined?(::ArJdbc::PostgreSQL::BindSubstitution)
    #                       ::ArJdbc::PostgreSQL::BindSubstitution
    #                     else
    #                       Mysql2
    #                     end

    class Mysql2Rgeo < MySQL  # :nodoc:
      include RGeo::ActiveRecord::SpatialToSql

      if ::Arel::Visitors.const_defined?(:BindVisitor)
        include ::Arel::Visitors::BindVisitor
      end

      FUNC_MAP = {
        'st_wkttosql' => 'ST_GeomFromText',
        'st_wkbtosql' => 'ST_GeomFromWKB',
        'st_length' => 'ST_Length'
      }.freeze

      def st_func(standard_name)
        FUNC_MAP[standard_name.downcase] || standard_name
      end

      def visit_Arel_Nodes_Values(o, collector)
        collector << "VALUES ("

        len = o.expressions.length - 1
        o.expressions.zip(o.columns).each_with_index { |(value, attr), i|
          case value
            when Nodes::SqlLiteral, Nodes::BindParam
              if column_for(attr).type == :spatial
                collector << 'ST_GeomFromText(?)'
              else
                collector = visit value, collector
              end
            else
              collector << quote(value, attr && column_for(attr)).to_s
          end
          unless i == len
            collector << COMMA
          end
        }

        collector << ")"
      end
    end
  end
end
