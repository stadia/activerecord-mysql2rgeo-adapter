require "test_helper"
require "active_record/schema_dumper"

class Mysql2SpatialTypesTest < ActiveSupport::TestCase # :nodoc:
  NEW_CONNECTION = {
    "adapter" => "mysql2rgeo",
    "host"               => "127.0.0.1",
    "database"           => "mysql2rgeo_tasks_test",
    "username"           => "root"
  }.freeze

  def setup
    setup_database_tasks
    connection.create_table("spatial_types", force: true) do |t|
      t.geometry   :geometry_field
      t.polygon    :polygon_field, null: false, index: { type: :spatial }
      t.point      :point_field
      t.linestring :linestring_field

      t.geometry   :geometry_multi, multi: true
      t.polygon    :polygon_multi, multi: true
      t.point      :point_multi, multi: true
      t.linestring :linestring_multi, multi: true
    end
  end

  def teardown
    connection.drop_table "spatial_types", if_exists: true
  end

  def test_schema_dump_includes_spatial_types
    File.open(tmp_sql_filename, "w:utf-8") do |file|
      ActiveRecord::SchemaDumper.dump(connection, file)
    end
    # schema = File.read(tmp_sql_filename)

    # assert_match %r{t.geometry\s+"geometry_field"$}, schema
    # assert_match %r{t.polygon\s+"polygon_field",\s+null: false$}, schema
    # assert_match %r{t.point\s+"point_field"$}, schema
    # assert_match %r{t.linestring\s+"linestring_field"$}, schema
    #
    # assert_match %r{t.geometry\s+"geometry_multi",\s+multi: true$}, schema
    # assert_match %r{t.polygon\s+"polygon_multi",\s+multi: true$}, schema
    # assert_match %r{t.point\s+"point_multi",\s+multi: true$}, schema
    # assert_match %r{t.linestring\s+"linestring_multi",\s+multi: true$}, schema
  end

  def test_schema_dump_can_be_restored
    File.open(tmp_sql_filename, "w:utf-8") do |file|
      ActiveRecord::SchemaDumper.dump(connection, file)
    end
    schema = File.read(tmp_sql_filename)
    connection.drop_table "spatial_types", if_exists: true

    eval schema

    File.open(tmp_sql_filename, "w:utf-8") do |file|
      ActiveRecord::SchemaDumper.dump(connection, file)
    end
    schema2 = File.read(tmp_sql_filename)

    assert_equal schema, schema2
  end

  private

  def connection
    ActiveRecord::Base.connection
  end

  def tmp_sql_filename
    File.expand_path("../tmp/tmp.sql", ::File.dirname(__FILE__))
  end

  def setup_database_tasks
    FileUtils.rm_f(tmp_sql_filename)
    FileUtils.mkdir_p(::File.dirname(tmp_sql_filename))
    drop_db_if_exists
    ActiveRecord::Tasks::MySQLDatabaseTasks.new(NEW_CONNECTION).create
  rescue ActiveRecord::Tasks::DatabaseAlreadyExists
    # ignore
  end

  def drop_db_if_exists
    ActiveRecord::Tasks::MySQLDatabaseTasks.new(NEW_CONNECTION).drop
  rescue ActiveRecord::Tasks::DatabaseAlreadyExists
    # ignore
  end
end
