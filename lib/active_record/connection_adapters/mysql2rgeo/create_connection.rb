if RUBY_ENGINE == "jruby"
  require "active_record/connection_adapters/jdbcmysql_adapter"
else
  require "mysql2"
end

module ActiveRecord # :nodoc:
  module ConnectionHandling # :nodoc:
    if RUBY_ENGINE == "jruby"

      def jdbcmysql2rgeo_connection(config)
        config[:adapter_class] = ConnectionAdapters::Mysql2RgeoAdapter
        mysql2_connection(config)
      end

      alias_method :jdbcmysql2rgeo_connection, :mysql2rgeo_connection

    else

      # Based on the default <tt>mysql2_connection</tt> definition from ActiveRecord.
      # https://github.com/rails/rails/blob/master/activerecord/lib/active_record/connection_adapters/mysql2_adapter.rb
      # FULL REPLACEMENT because we need to create a different class.

      def mysql2rgeo_connection(config)
        config = config.symbolize_keys

        config[:username] = 'root' if config[:username].nil?
        config[:flags] ||= 0

        if Mysql2::Client.const_defined? :FOUND_ROWS
          if config[:flags].is_a? Array
            config[:flags].push "FOUND_ROWS".freeze
          else
            config[:flags] |= Mysql2::Client::FOUND_ROWS
          end
        end

        client = Mysql2::Client.new(config)
        ConnectionAdapters::Mysql2RgeoAdapter.new(client, logger, nil, config)
      rescue Mysql2::Error => error
        if error.message.include?("Unknown database")
          raise ActiveRecord::NoDatabaseError
        else
          raise
        end
      end
    end
  end
end
