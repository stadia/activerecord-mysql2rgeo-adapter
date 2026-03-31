# frozen_string_literal: true

module ActiveRecord # :nodoc:
  module ConnectionAdapters # :nodoc:
    module Mysql2Rgeo # :nodoc:
      class TableDefinition < MySQL::TableDefinition # :nodoc:
        include ColumnMethods

        # super: https://github.com/rails/rails/blob/master/activerecord/lib/active_record/connection_adapters/abstract/schema_definitions.rb
        def new_column_definition(name, type, **options)
          spatial_type = type.to_sym == :virtual ? options[:type]&.to_sym : type.to_sym

          if spatial_type && (info = Mysql2RgeoAdapter.spatial_column_options(spatial_type))
            if (limit = options.delete(:limit)) && limit.is_a?(::Hash)
              options.merge!(limit)
            end

            geo_type = if type.to_sym == :virtual
                         "GEOMETRY"
                       else
                         ColumnDefinitionUtils.geo_type(options[:type] || spatial_type || info[:type])
                       end

            if type.to_sym == :virtual
              options.delete(:srid)
            else
              options[:srid] ||= ColumnDefinitionUtils.default_srid(options)
              options[:comment] = ColumnDefinitionUtils.add_metadata_comment(
                options[:comment],
                geographic: options[:geographic],
                has_m: options[:has_m],
                has_z: options[:has_z],
                array: options[:array],
                default: options[:default],
                srid: options[:srid],
                geo_type: geo_type
              )
            end

            options[:spatial_type] = geo_type
            column = if type.to_sym == :virtual
                       super(name, type, **options.merge(type: geo_type.downcase.to_sym))
                     else
                       super(name, geo_type.downcase.to_sym, **options)
                     end
          else
            if options[:array]
              options[:comment] =
                ColumnDefinitionUtils.add_metadata_comment(options[:comment], array: options[:array])
            end
            column = super
          end

          column
        end

        def valid_column_definition_options
          super + %i[array geographic has_m has_z spatial_type srid]
        end
      end

      class Table < MySQL::Table # :nodoc:
        include ColumnMethods
      end

      module ColumnDefinitionUtils
        METADATA_TOKENS = {
          geographic: "mysql2rgeo:geographic",
          has_m: "mysql2rgeo:has_m",
          has_z: "mysql2rgeo:has_z",
          array: "mysql2rgeo:array",
          default_prefix: "mysql2rgeo:default:"
        }.freeze

        class << self
          def geo_type(type = "GEOMETRY")
            type.to_s.sub(/\Ast_/, "").delete("_").upcase
          end

          def default_srid(options)
            options[:geographic] ? 4326 : Mysql2RgeoAdapter::DEFAULT_SRID
          end

          def add_metadata_comment(comment, geographic: false, has_m: false, has_z: false, array: false, default: nil, srid: nil,
geo_type: nil)
            values = [comment]
            values << METADATA_TOKENS[:geographic] if geographic
            values << METADATA_TOKENS[:has_m] if has_m
            values << METADATA_TOKENS[:has_z] if has_z
            values << METADATA_TOKENS[:array] if array
            if default
              values << "#{METADATA_TOKENS[:default_prefix]}#{encode_default(default, geographic: geographic, srid: srid,
                                                                                      geo_type: geo_type, has_m: has_m, has_z: has_z)}"
            end
            values.compact_blank.join(" ")
          end

          def extract_metadata(comment)
            text = comment.to_s
            default_hex = text[/#{Regexp.escape(METADATA_TOKENS[:default_prefix])}([0-9A-F]+)/i, 1]
            {
              geographic: text.include?(METADATA_TOKENS[:geographic]),
              has_m: text.include?(METADATA_TOKENS[:has_m]),
              has_z: text.include?(METADATA_TOKENS[:has_z]),
              array: text.include?(METADATA_TOKENS[:array]),
              default_hex: default_hex,
            }
          end

          def strip_metadata_comment(comment)
            text = comment.to_s
            METADATA_TOKENS.each_value do |token|
              text = text.gsub(token, "")
            end
            text = text.gsub(/mysql2rgeo:default:[0-9A-F]+/i, "")
            text.squeeze(" ").strip.presence
          end

          def encode_default(default, geographic:, srid:, geo_type:, has_m:, has_z:)
            type = ActiveRecord::Type::Spatial.new(
              geographic ? "geography" : "geometry",
              geo_type: ActiveRecord::Type::Spatial.normalize_geo_type(geo_type),
              srid: srid,
              geographic: geographic,
              has_z: has_z,
              has_m: has_m
            )
            geometry = type.serialize(default)
            geometry = RGeo::Feature.cast(geometry, factory: type.send(:spatial_factory), project: true) if geographic

            wkb = RGeo::WKRep::WKBGenerator.new(
              hex_format: true,
              little_endian: true,
              type_format: :wkb11,
              emit_ewkb_srid: false
            ).generate(geometry).upcase
            geographic ? with_ewkb_srid(wkb, srid) : wkb
          end

          def with_ewkb_srid(wkb, srid)
            endian = wkb[0, 2]
            type_hex = wkb[2, 8]
            body = wkb[10..]
            type = [type_hex].pack("H*").unpack1("V") | 0x20000000
            srid_hex = [srid.to_i].pack("V").unpack1("H*").upcase
            "#{endian}#{[type].pack('V').unpack1('H*').upcase}#{srid_hex}#{body}"
          end
        end
      end
    end
  end
end
