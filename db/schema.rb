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

ActiveRecord::Schema.define(version: 20160713043725) do

  create_table "branches", force: :cascade do |t|
    t.datetime "git_tested_at"
    t.datetime "git_updated_at",              null: false
    t.text     "name",           limit: 1024, null: false
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "author_id"
    t.integer  "repository_id"
  end

  add_index "branches", ["author_id"], name: "index_branches_on_author_id"
  add_index "branches", ["repository_id"], name: "index_branches_on_repository_id"

  create_table "conflicts", force: :cascade do |t|
    t.boolean  "resolved",                 default: false, null: false
    t.datetime "status_last_changed_date",                 null: false
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "branch_a_id"
    t.integer  "branch_b_id"
    t.string   "conflicting_files",        default: "[]",  null: false
  end

  add_index "conflicts", ["branch_a_id"], name: "index_conflicts_on_branch_a_id"
  add_index "conflicts", ["branch_b_id"], name: "index_conflicts_on_branch_b_id"

  create_table "delayed_jobs", force: :cascade do |t|
    t.integer  "priority",   default: 0, null: false
    t.integer  "attempts",   default: 0, null: false
    t.text     "handler",                null: false
    t.text     "last_error"
    t.datetime "run_at"
    t.datetime "locked_at"
    t.datetime "failed_at"
    t.string   "locked_by"
    t.string   "queue"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "delayed_jobs", ["priority", "run_at"], name: "delayed_jobs_priority"

  create_table "merges", force: :cascade do |t|
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "source_branch_id"
    t.integer  "target_branch_id"
    t.boolean  "successful",       null: false
  end

  add_index "merges", ["source_branch_id"], name: "index_merges_on_source_branch_id"
  add_index "merges", ["target_branch_id"], name: "index_merges_on_target_branch_id"

  create_table "notification_suppressions", force: :cascade do |t|
    t.datetime "suppress_until"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "user_id"
    t.integer  "branch_id"
    t.string   "type"
    t.integer  "conflict_id"
  end

  add_index "notification_suppressions", ["branch_id"], name: "index_notification_suppressions_on_branch_id"
  add_index "notification_suppressions", ["conflict_id"], name: "index_notification_suppressions_on_conflict_id"
  add_index "notification_suppressions", ["type"], name: "index_notification_suppressions_on_type"
  add_index "notification_suppressions", ["user_id"], name: "index_notification_suppressions_on_user_id"

  create_table "repositories", force: :cascade do |t|
    t.text     "name",       limit: 1024, null: false
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "users", force: :cascade do |t|
    t.text     "name",         limit: 255,                 null: false
    t.text     "email",        limit: 255,                 null: false
    t.datetime "created_at"
    t.datetime "updated_at"
    t.boolean  "unsubscribed",             default: false, null: false
  end

end
