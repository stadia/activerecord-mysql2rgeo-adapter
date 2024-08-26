# frozen_string_literal: true

require "active_record/connection_adapters/mysql2rgeo_adapter"

ActiveRecord::ConnectionAdapters.register('mysql2rgeo', 'ActiveRecord::ConnectionAdapters::Mysql2RgeoAdapter', 'active_record/connection_adapters/mysql2rgeo_adapter')
