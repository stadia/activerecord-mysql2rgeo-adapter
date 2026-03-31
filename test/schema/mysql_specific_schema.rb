# frozen_string_literal: true

load SCHEMA_ROOT + "/mysql2_specific_schema.rb" if defined?(SCHEMA_ROOT)

ActiveRecord::Schema.define do
  create_table :limitless_fields, force: true do |t|
    t.binary :binary, limit: 100_000
    t.text :text, limit: 100_000
  end

  create_table :bigint_array, force: true do |t|
    t.text :big_int_data_points
    t.text :decimal_array_default
  end

  create_table :uuid_parents, id: false, force: true do |t|
    t.string :id, limit: 36, primary_key: true
    t.string :name
  end

  create_table :uuid_children, id: false, force: true do |t|
    t.string :id, limit: 36, primary_key: true
    t.string :name
    t.string :uuid_parent_id, limit: 36
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

  create_table :measurements, id: false, force: true do |t|
    t.string :city_id, null: false
    t.date :logdate, null: false
    t.integer :peaktemp
    t.integer :unitsales
    t.index %i[logdate city_id], unique: true
  end
end
