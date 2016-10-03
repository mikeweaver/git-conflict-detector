class CreateJiraIssues < ActiveRecord::Migration
  def self.up
    create_table :jira_issues do |t|
      t.text     :key, :limit => 255, :null => false
      t.text     :issue_type, :limit => 255, :null => false
      t.text     :summary, :limit => 1024, :null => false
      t.text     :status, :limit => 255, :null => false
      t.date     :targeted_deploy_date
      t.datetime :created_at
      t.datetime :updated_at
      t.integer  :assignee_id
      t.integer  :parent_issue_id
    end
    add_index :jira_issues, [:assignee_id]
    add_index :jira_issues, [:parent_issue_id]

    create_table :jira_issues_and_pushes, :id => false do |t|
      t.integer :jira_issue_id
      t.integer :push_id
    end
  end

  def self.down
    drop_table :jira_issues
    drop_table :jira_issues_and_pushes
  end
end
