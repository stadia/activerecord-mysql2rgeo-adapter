# frozen_string_literal: true

module ActiveRecord
  module ConnectionAdapters
    module Mysql2Rgeo
      module SchemaStatements
        # super: https://github.com/rails/rails/blob/master/activerecord/lib/active_record/connection_adapters/mysql/schema_statements.rb

        # override
        def indexes(table_name) # :nodoc:
          indexes = super
          # HACK(aleks, 06/15/18): MySQL 5 does not support prefix lengths for spatial indexes
          # https://dev.mysql.com/doc/refman/5.6/en/create-index.html
          indexes.select do |idx|
            idx.type == :spatial
          end.each do |idx|
            if idx.is_a?(Struct)
              idx.lengths = {}
              idx.using = :gist if idx.members.include?(:using)
            else
              idx.instance_variable_set(:@lengths, {})
              idx.instance_variable_set(:@using, :gist)
            end
          end
          indexes
        end

        def add_index(table_name, column_name, **options) # :nodoc:
          if options[:using]&.to_sym == :gist
            Array(column_name).each do |name|
              column = columns(table_name).find { |col| col.name == name.to_s }
              next unless column&.spatial? && column.null

              column_options = column.limit.is_a?(Hash) ? column.limit.symbolize_keys.except(:type) : {}
              column_options[:comment] = column.comment if column.comment.present?
              change_column(table_name, name, column.limit[:type].to_sym, **column_options, null: false)
            end
          end

          super
        end

        # override
        def type_to_sql(type, limit: nil, precision: nil, scale: nil, unsigned: nil, **) # :nodoc:
          return "geometry(#{limit})" if type.to_sym == :geometry && limit.is_a?(String)

          if RGeo::ActiveRecord.geometric_type_from_name(type.to_s.delete("_"))
            type = limit[:type] || type if limit.is_a?(::Hash)
            type = type.to_s.delete("_").upcase
          end
          super
        end

        def update_table_definition(table_name, base)
          Mysql2Rgeo::Table.new(table_name, base)
        end

        private

        # override
        def schema_creation
          Mysql2Rgeo::SchemaCreation.new(self)
        end

        # override
        def create_table_definition(*, **)
          Mysql2Rgeo::TableDefinition.new(self, *, **)
        end

        # override
        def new_column_from_field(table_name, field, _definitions)
          field_name = field_value(field, "Field")
          type_metadata = fetch_type_metadata(field_value(field, "Type"), field_value(field, "Extra"))
          default = field_value(field, "Default")
          default_function = nil
          metadata_comment = field_value(field, "Comment")
          metadata = Mysql2Rgeo::ColumnDefinitionUtils.extract_metadata(metadata_comment)
          comment = Mysql2Rgeo::ColumnDefinitionUtils.strip_metadata_comment(metadata_comment)
          default = metadata[:default_hex] if default.nil? && metadata[:default_hex].present?

          if type_metadata.type == :datetime && /\ACURRENT_TIMESTAMP(?:\([0-6]?\))?\z/i.match?(default)
            default_function = default
            default = nil
          elsif type_metadata.extra == "DEFAULT_GENERATED"
            if default == "NULL" && metadata[:default_hex].present?
              default = metadata[:default_hex]
            elsif default == "NULL"
              default = generated_default_for(table_name, field_name)
            end

            if default&.match?(/\Ast_geomfromtext\(/i)
              default = "(#{default})" unless default.start_with?("(")
              default_function = default
              default = nil
            end
          end

          if type_metadata.extra.to_s.match?(/(?:VIRTUAL|STORED|PERSISTENT)\s+GENERATED/i)
            default_function = generation_expression_for(table_name, field_name)
          end

          # {:dimension=>2, :has_m=>false, :has_z=>false, :name=>"latlon", :srid=>0, :type=>"GEOMETRY"}
          spatial = spatial_column_info(table_name).get(field_name, type_metadata.sql_type)
          if spatial
            spatial[:has_z] ||= metadata[:has_z]
            spatial[:has_m] ||= metadata[:has_m]
            spatial[:geographic] ||= metadata[:geographic]
            geo_type = spatial[:type].camelize
            geo_type = "#{geo_type}Z" if spatial[:has_z]
            geo_type = "#{geo_type}M" if spatial[:has_m]
            sql_type = if spatial[:geographic]
                         "geography(#{geo_type},#{spatial[:srid]})"
                       else
                         "geometry(#{geo_type},#{spatial[:srid]})"
                       end
            type_metadata = MySQL::TypeMetadata.new(
              ConnectionAdapters::SqlTypeMetadata.new(
                sql_type: sql_type,
                type: :geometry,
                limit: nil,
                precision: type_metadata.precision,
                scale: type_metadata.scale
              ),
              extra: type_metadata.extra
            )

            if default_function&.match?(/\A\(?st_geomfromtext\(/i)
              default = extract_spatial_default_hex(default_function, spatial)
              default_function = nil
            end
          end

          SpatialColumn.new(
            field_name,
            lookup_cast_type(type_metadata.sql_type),
            default,
            type_metadata,
            field_value(field, "Null") == "YES",
            default_function,
            collation: field_value(field, "Collation"),
            comment: comment,
            spatial: spatial,
            array: metadata[:array]
          )
        end

        # memoize hash of column infos for tables
        def spatial_column_info(table_name)
          @spatial_column_info ||= {}
          @spatial_column_info[table_name.to_sym] = SpatialColumnInfo.new(self, table_name.to_s)
        end

        def field_value(field, key)
          field[key] || field[key.to_sym]
        end

        def extract_spatial_default_hex(default_function, spatial)
          default_sql = default_function.delete_prefix("(").delete_suffix(")").delete("\\")
          match = default_sql.match(/\Ast_geomfromtext\(_utf8mb4'(.+?)',\s*(\d+)\)\z/i)
          return unless match

          wkt = match[1]
          srid = match[2].to_i
          type = ActiveRecord::Type::Spatial.new(
            spatial[:geographic] ? "geography" : "geometry",
            geo_type: ActiveRecord::Type::Spatial.normalize_geo_type(spatial[:type]),
            srid: srid,
            geographic: spatial[:geographic],
            has_z: spatial[:has_z],
            has_m: spatial[:has_m]
          )
          geometry = type.serialize(wkt)
          return unless geometry

          geometry = RGeo::Feature.cast(geometry, factory: type.send(:spatial_factory), project: true) if spatial[:geographic]

          wkb = RGeo::WKRep::WKBGenerator.new(
            hex_format: true,
            little_endian: true,
            type_format: :wkb11,
            emit_ewkb_srid: false
          ).generate(geometry)
          wkb = wkb.upcase
          return wkb unless spatial[:geographic]

          endian = wkb[0, 2]
          type_hex = wkb[2, 8]
          body = wkb[10..]
          type = [type_hex].pack("H*").unpack1("V") | 0x20000000
          srid_hex = [spatial[:srid].to_i].pack("V").unpack1("H*").upcase
          "#{endian}#{[type].pack('V').unpack1('H*').upcase}#{srid_hex}#{body}"
        end

        def generation_expression_for(table_name, column_name)
          query_value(<<~SQL)&.gsub("`", "")
            SELECT generation_expression
            FROM information_schema.columns
            WHERE table_schema = DATABASE()
              AND table_name = #{quote(table_name)}
              AND column_name = #{quote(column_name)}
          SQL
                             &.gsub(/st_buffer\(([^,]+),\s*(\d+)\)/i, 'st_buffer(\1, (\2)::double precision)')
        end

        def generated_default_for(table_name, column_name)
          query_value(<<~SQL)
            SELECT column_default
            FROM information_schema.columns
            WHERE table_schema = DATABASE()
              AND table_name = #{quote(table_name)}
              AND column_name = #{quote(column_name)}
          SQL
        end
      end
    end
  end
end
