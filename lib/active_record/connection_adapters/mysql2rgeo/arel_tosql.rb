# frozen_string_literal: true

module Arel # :nodoc:
  module Visitors # :nodoc:
    # Different super-class under JRuby JDBC adapter.
    MySQLSuperclass = if defined?(::ArJdbc::MySQL::BindSubstitution)
                        ::ArJdbc::MySQL::BindSubstitution
                      else
                        MySQL
                      end

    class Mysql2Rgeo < MySQLSuperclass # :nodoc:
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
        node, srid = Mysql2Rgeo.parse_node(node)
        collector << if srid == 0
                       "#{st_func('ST_WKTToSQL')}(#{quote(node)})"
                     else
                       "#{st_func('ST_WKTToSQL')}(#{quote(node)}, #{srid}, 'axis-order=long-lat')"
                     end
      end

      def visit_RGeo_ActiveRecord_SpatialNamedFunction(node, collector)
        aggregate(st_func(node.name), node, collector)
      end

      def visit_in_spatial_context(node, collector)
        case node
        when String
          node, srid = Mysql2Rgeo.parse_node(node)
          collector << if srid == 0
                         "#{st_func('ST_WKTToSQL')}(#{quote(node)})"
                       else
                         "#{st_func('ST_WKTToSQL')}(#{quote(node)}, #{srid}, 'axis-order=long-lat')"
                       end
        when RGeo::Feature::Instance
          collector << visit_RGeo_Feature_Instance(node, collector)
        when RGeo::Cartesian::BoundingBox
          collector << visit_RGeo_Cartesian_BoundingBox(node, collector)
        else
          visit(node, collector)
        end
      end

      def self.parse_node(node)
        value, srid = nil, 0
        if node =~ /.*;.*$/i
          params = Regexp.last_match(0).split(";")
          if params.first =~ /(srid|SRID)=\d*/
            srid = params.first.split("=").last.to_i
          else
            value = params.first
          end
          if params.last =~ /(srid|SRID)=\d*/
            srid = params.last.split("=").last.to_i
          else
            value = params.last
          end
        else
          value = node
        end
        [value, srid]
      end
    end
  end
end
