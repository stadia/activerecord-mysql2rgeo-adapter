require "test_helper"
require "active_record/schema_dumper"

class TasksTest < ActiveSupport::TestCase  # :nodoc:
  NEW_CONNECTION = {
    "adapter"            => "mysql2rgeo",
    "host"               => "127.0.0.1",
    "port"               => "3306",
    "username"               => "root",
    "database"           => "mysql2rgeo_tasks_test"
  }.freeze

  def test_empty_sql_dump
    setup_database_tasks
    ActiveRecord::Tasks::DatabaseTasks.structure_dump(NEW_CONNECTION, tmp_sql_filename)
    sql = File.read(tmp_sql_filename)
    assert(sql !~ /CREATE TABLE/)
  end

  def test_sql_dump
    setup_database_tasks
    connection.create_table(:spatial_test, force: true) do |t|
      t.point "latlon", geographic: true
      t.geometry "geo_col", srid: 4326
      t.column "poly", :multi_polygon, srid: 4326
    end
    ActiveRecord::Tasks::DatabaseTasks.structure_dump(NEW_CONNECTION, tmp_sql_filename)
    data = File.read(tmp_sql_filename)
    assert(data.index("`latlon` point"))
    assert(data.index("`geo_col` geometry"))
    assert(data.index("`poly` multipolygon"))
  end

  def test_empty_schema_dump
    setup_database_tasks
    File.open(tmp_sql_filename, "w:utf-8") do |file|
      ActiveRecord::SchemaDumper.dump(::ActiveRecord::Base.connection, file)
    end
    data = File.read(tmp_sql_filename)
    assert(data.index("ActiveRecord::Schema"))
  end

  def test_basic_geometry_schema_dump
    setup_database_tasks
    connection.create_table(:spatial_test, force: true) do |t|
      t.geometry "object1"
      t.spatial "object2", srid: connection.default_srid, limit: { type: "geometry" }
    end
    File.open(tmp_sql_filename, "w:utf-8") do |file|
      ActiveRecord::SchemaDumper.dump(connection, file)
    end
    data = File.read(tmp_sql_filename)
    assert data.index("t.spatial \"object1\", limit: {:type=>\"geometry\"}")
    assert data.index("t.spatial \"object2\", limit: {:type=>\"geometry\"}")
  end

  def test_basic_geography_schema_dump
    setup_database_tasks
    connection.create_table(:spatial_test, force: true) do |t|
      t.point "latlon1", geographic: true
      t.spatial "latlon2", srid: 4326, geographic: true, limit: { type: "point" }
    end
    File.open(tmp_sql_filename, "w:utf-8") do |file|
      ActiveRecord::SchemaDumper.dump(connection, file)
    end
    data = File.read(tmp_sql_filename)
    assert data.index(%(t.spatial "latlon1", limit: {:type=>"point"}))
    assert data.index(%(t.spatial "latlon2", limit: {:type=>"point"}))
  end

  def test_index_sql_dump
    setup_database_tasks
    connection.create_table(:spatial_test, force: true) do |t|
      t.point "latlon", null: false, geographic: true
      t.string "name"
    end
    connection.add_index :spatial_test, :latlon, type: :spatial
    connection.add_index :spatial_test, :name, using: :btree
    ActiveRecord::Tasks::DatabaseTasks.structure_dump(NEW_CONNECTION, tmp_sql_filename)
    data = File.read(tmp_sql_filename)
    assert(data.index("`latlon` point NOT NULL"))
    assert data.index("SPATIAL KEY `index_spatial_test_on_latlon` (`latlon`)")
    assert data.index("KEY `index_spatial_test_on_name` (`name`) USING BTREE")
  end

  def test_index_schema_dump
    setup_database_tasks
    connection.create_table(:spatial_test, force: true) do |t|
      t.point "latlon", null:false, geographic: true
    end
    connection.add_index :spatial_test, :latlon, type: :spatial
    File.open(tmp_sql_filename, "w:utf-8") do |file|
      ActiveRecord::SchemaDumper.dump(connection, file)
    end
    data = File.read(tmp_sql_filename)
    puts data
    # assert data.index(%(t.point "latlon", limit: {:srid=>4326, :type=>"point", :geographic=>true}))
    # assert data.index(%(t.index ["latlon"], name: "index_spatial_test_on_latlon", type: :spatial))
  end

  def test_add_index_with_no_options
    setup_database_tasks
    connection.create_table(:test, force: true) do |t|
      t.string "name"
    end
    connection.add_index :test, :name
    ActiveRecord::Tasks::DatabaseTasks.structure_dump(NEW_CONNECTION, tmp_sql_filename)
    data = File.read(tmp_sql_filename)
    assert data.index("KEY `index_test_on_name` (`name`)")
  end

  def test_add_index_via_references
    setup_database_tasks
    connection.create_table(:cats, force: true)
    connection.create_table(:dogs, force: true) do |t|
      t.references :cats, index: true
    end
    ActiveRecord::Tasks::DatabaseTasks.structure_dump(NEW_CONNECTION, tmp_sql_filename)
    data = File.read(tmp_sql_filename)
    assert data.index("KEY `index_dogs_on_cats_id` (`cats_id`)")
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
