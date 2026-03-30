# frozen_string_literal: true

module Arel # :nodoc:
  module Visitors # :nodoc:
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
        node, srid = Mysql2Rgeo.parse_node(node)
        collector << if srid == 0
                       "#{st_func('ST_WKTToSQL')}(#{quote(node)})"
                     else
                       "#{st_func('ST_WKTToSQL')}(#{quote(node)}, #{srid})"
                     end
      end
      alias visit_RGeo_Feature_Instance visit_String
      alias visit_RGeo_Cartesian_BoundingBox visit_String

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
                         "#{st_func('ST_WKTToSQL')}(#{quote(node)}, #{srid})"
                       end
        when RGeo::Feature::Instance
          visit_RGeo_Feature_Instance(node, collector)
        when RGeo::Cartesian::BoundingBox
          visit_RGeo_Cartesian_BoundingBox(node, collector)
        else
          visit(node, collector)
        end
      end

      def self.parse_node(node)
        if RGeo::Feature::Instance === node
          wkt = RGeo::WKRep::WKTGenerator.new(tag_format: :wkt11, emit_ewkt_srid: false).generate(node)
          return [wkt, node.srid]
        end

        if RGeo::Cartesian::BoundingBox === node
          geometry = node.to_geometry
          wkt = RGeo::WKRep::WKTGenerator.new(tag_format: :wkt11, emit_ewkt_srid: false).generate(geometry)
          return [wkt, geometry.srid]
        end

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
