# encoding: UTF-8
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

ActiveRecord::Schema.define(version: 20151031011820) do

  create_table "branches", force: :cascade do |t|
    t.datetime "git_tested_at"
    t.datetime "git_updated_at",              null: false
    t.text     "name",           limit: 1024, null: false
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "author_id"
  end

  add_index "branches", ["author_id"], name: "index_branches_on_author_id"

  create_table "conflicts", force: :cascade do |t|
    t.boolean  "resolved",         null: false
    t.datetime "last_tested_date", null: false
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "branch_a_id"
    t.integer  "branch_b_id"
  end

  add_index "conflicts", ["branch_a_id"], name: "index_conflicts_on_branch_a_id"
  add_index "conflicts", ["branch_b_id"], name: "index_conflicts_on_branch_b_id"

  create_table "user_branches", id: false, force: :cascade do |t|
    t.integer "branch_id"
    t.integer "user_id"
  end

  create_table "users", force: :cascade do |t|
    t.text     "name",       limit: 255, null: false
    t.text     "email",      limit: 255, null: false
    t.datetime "created_at"
    t.datetime "updated_at"
  end

end
