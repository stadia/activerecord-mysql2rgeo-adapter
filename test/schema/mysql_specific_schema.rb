# frozen_string_literal: true

# This is a mysql-compatible subset of Active Record's adapter-specific test
# schema.

ActiveRecord::Schema.define do
  create_table :uuid_parents, id: false, force: true do |t|
    t.string :id, limit: 36, primary_key: true
    t.string :name
  end

  create_table :uuid_children, id: false, force: true do |t|
    t.string :id, limit: 36, primary_key: true
    t.string :name
    t.string :uuid_parent_id, limit: 36
  end

  create_table :defaults, force: true do |t|
    t.date :modified_date, default: "2004-01-01"
    t.date :modified_date_function, default: "2004-01-01"
    t.date :fixed_date, default: "2004-01-01"
    t.datetime :modified_time, default: "2004-01-01 00:00:00"
    t.datetime :modified_time_without_precision, precision: nil, default: "2004-01-01 00:00:00"
    t.datetime :modified_time_with_precision_0, precision: 0, default: "2004-01-01 00:00:00"
    t.datetime :modified_time_function, default: "2004-01-01 00:00:00"
    t.datetime :fixed_time, default: "2004-01-01 00:00:00"
    t.datetime :fixed_time_with_time_zone, default: "2004-01-01 00:00:00"
    t.column :char1, "char(1)", default: "Y"
    t.string :char2, limit: 50, default: "a varchar field"
    t.text :char3
    t.bigint :bigint_default, default: 0
    t.text :multiline_default
  end

  # This table is to verify if the :limit option is being ignored for text and binary columns
  create_table :limitless_fields, force: true do |t|
    t.binary :binary, limit: 100_000
    t.text :text, limit: 100_000
  end

  create_table :bigint_array, force: true do |t|
    t.text :big_int_data_points
    t.text :decimal_array_default
  end

  create_table :uuid_comments, force: true, id: false do |t|
    t.string :uuid, limit: 36, primary_key: true
    t.string :content
  end

  create_table :uuid_entries, force: true, id: false do |t|
    t.string :uuid, limit: 36, primary_key: true
    t.string :entryable_type, null: false
    t.string :entryable_uuid, limit: 36, null: false
  end

  create_table :uuid_items, force: true, id: false do |t|
    t.string :uuid, limit: 36, primary_key: true
    t.string :title
  end

  create_table :uuid_messages, force: true, id: false do |t|
    t.string :uuid, limit: 36, primary_key: true
    t.string :subject
  end

  create_table(:measurements, id: false, force: true) do |t|
    t.string :city_id, null: false
    t.date :logdate, null: false
    t.integer :peaktemp
    t.integer :unitsales
    t.index %i[logdate city_id], unique: true
  end
end
