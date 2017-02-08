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

      def visit_Arel_Nodes_SelectCore(o, collector)
        len = o.projections.length - 1
        if len == 0
          if !o.projections.first.nil? && o.projections.first.respond_to?(:relation)
            projections = []
            column_cache(o.projections.first.relation.name).keys.each do |x|
              projections << o.projections.first.relation[x.to_sym]
            end
            o.projections = projections
          end
        end
        super
      end

      def visit_Arel_Attributes_Attribute(o, collector)
        join_name = o.relation.table_alias || o.relation.name

        collector << if (!column_for(o).nil? && column_for(o).type == :spatial) && !collector.value.include?(" WHERE ")
                       "ST_AsText(#{quote_table_name join_name}.#{quote_column_name o.name}) as #{quote_column_name o.name}"
                     else
                       "#{quote_table_name join_name}.#{quote_column_name o.name}"
                     end
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
