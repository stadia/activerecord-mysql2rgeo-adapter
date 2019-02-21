module Arel  # :nodoc:
  module Visitors  # :nodoc:
    # Different super-class under JRuby JDBC adapter.
    MySQLSuperclass = if defined?(::ArJdbc::MySQL::BindSubstitution)
                        ::ArJdbc::MySQL::BindSubstitution
                      else
                        MySQL
                      end

    class Mysql2Rgeo < MySQLSuperclass  # :nodoc:
      include RGeo::ActiveRecord::SpatialToSql

      if ::Arel::Visitors.const_defined?(:BindVisitor)
        include ::Arel::Visitors::BindVisitor
      end

      FUNC_MAP = {
        "st_wkttosql" => "ST_GeomFromText",
        "st_wkbtosql" => "ST_GeomFromWKB",
        "st_length" => "ST_Length"
      }.freeze

      def st_func(standard_name)
        FUNC_MAP[standard_name.downcase] || standard_name
      end

      def visit_String(node, collector)
        collector << "#{st_func('ST_WKTToSQL')}(#{quote(node)})"
      end

      def visit_RGeo_ActiveRecord_SpatialNamedFunction(node, collector)
        aggregate(st_func(node.name), node, collector)
      end
    end
  end
end
