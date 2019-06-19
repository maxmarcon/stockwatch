# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your
# database schema. If you need to create the application database on another
# system, you should be using db:schema:load, not running all the migrations
# from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 2019_06_18_135519) do

  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "figis", force: :cascade do |t|
    t.string "figi", null: false
    t.string "isin"
    t.string "name", null: false
    t.string "ticker", null: false
    t.string "unique_id", null: false
    t.string "exch_code"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["figi"], name: "index_figis_on_figi", unique: true
  end

  create_table "iex_symbols", force: :cascade do |t|
    t.string "symbol", null: false
    t.string "exchange"
    t.string "name", null: false
    t.date "date", null: false
    t.string "type", null: false
    t.string "iex_id", null: false
    t.string "region", limit: 2, null: false
    t.string "currency", limit: 3, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["iex_id"], name: "index_iex_symbols_on_iex_id", unique: true
  end

end
