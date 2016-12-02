class RemovePreDeployCheckerModels < ActiveRecord::Migration
  def self.up
    drop_table :delayed_jobs
    drop_table :pushes
    drop_table :commits_and_pushes
    drop_table :jira_issues_and_pushes
    drop_table :jira_issues

    remove_column :commits, :jira_issue_id

    remove_index :commits, :name => :index_commits_on_jira_issue_id rescue ActiveRecord::StatementInvalid
  end

  def self.down
    add_column :commits, :jira_issue_id, :integer

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

    create_table "pushes", force: :cascade do |t|
      t.string   "status",         limit: 32
      t.datetime "created_at"
      t.datetime "updated_at"
      t.integer  "head_commit_id"
      t.integer  "branch_id"
    end

    add_index "pushes", ["branch_id"], name: "index_pushes_on_branch_id"
    add_index "pushes", ["head_commit_id"], name: "index_pushes_on_head_commit_id"

    create_table "commits_and_pushes", force: :cascade do |t|
      t.integer "commit_id"
      t.integer "push_id"
      t.string  "errors_json",   limit: 256
      t.boolean "ignore_errors",             default: false
    end

    add_index "commits_and_pushes", ["commit_id"], name: "index_commits_and_pushes_on_commit_id"
    add_index "commits_and_pushes", ["push_id"], name: "index_commits_and_pushes_on_push_id"

    create_table "jira_issues_and_pushes", force: :cascade do |t|
      t.integer "jira_issue_id"
      t.integer "push_id"
      t.string  "errors_json",   limit: 256
      t.boolean "ignore_errors",             default: false
    end

    add_index "jira_issues_and_pushes", ["jira_issue_id"], name: "index_jira_issues_and_pushes_on_jira_issue_id"
    add_index "jira_issues_and_pushes", ["push_id"], name: "index_jira_issues_and_pushes_on_push_id"

    create_table "jira_issues", force: :cascade do |t|
      t.text     "key",                      limit: 255,  null: false
      t.text     "issue_type",               limit: 255,  null: false
      t.text     "summary",                  limit: 1024, null: false
      t.text     "status",                   limit: 255,  null: false
      t.date     "targeted_deploy_date"
      t.datetime "created_at"
      t.datetime "updated_at"
      t.integer  "assignee_id"
      t.integer  "parent_issue_id"
      t.text     "post_deploy_check_status", limit: 255
      t.text     "deploy_type",              limit: 255
    end

    add_index "jira_issues", ["assignee_id"], name: "index_jira_issues_on_assignee_id"
    add_index "jira_issues", ["parent_issue_id"], name: "index_jira_issues_on_parent_issue_id"

    add_index :commits, [:jira_issue_id]
  end
end
