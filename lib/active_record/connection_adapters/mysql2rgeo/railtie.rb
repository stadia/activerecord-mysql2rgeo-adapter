require "rails/railtie"
require "active_record/connection_adapters/mysql2rgeo_adapter"

module ActiveRecord  # :nodoc:
  module ConnectionAdapters  # :nodoc:
    module Mysql2Rgeo  # :nodoc:
      class Railtie < ::Rails::Railtie  # :nodoc:
        rake_tasks do
          load ::File.expand_path("databases.rake", ::File.dirname(__FILE__))
        end
      end
    end
  end
end
