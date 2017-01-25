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
              if column_for(attr)&.type == :spatial
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

      def visit_Arel_Nodes_SelectCore o, collector
        collector << "SELECT"

        collector = maybe_visit o.top, collector

        collector = maybe_visit o.set_quantifier, collector

        collect_nodes_for o.projections, collector, SPACE

        if o.source && !o.source.empty?
          collector << " FROM "
          collector = visit o.source, collector
        end

        collect_nodes_for o.wheres, collector, WHERE, AND
        collect_nodes_for o.groups, collector, GROUP_BY
        unless o.havings.empty?
          collector << " HAVING "
          inject_join o.havings, collector, AND
        end
        collect_nodes_for o.windows, collector, WINDOW

        collector
      end

      def visit_Arel_Attributes_Attribute o, collector
        join_name = o.relation.table_alias || o.relation.name

        if column_for(o).type == :spatial
          collector << "ST_AsText(#{quote_table_name join_name}.#{quote_column_name o.name}) as #{quote_column_name o.name}"
        else
          collector << "#{quote_table_name join_name}.#{quote_column_name o.name}"
        end
      end
    end
  end
end
