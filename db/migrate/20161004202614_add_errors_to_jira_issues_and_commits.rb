class AddErrorsToJiraIssuesAndCommits < ActiveRecord::Migration
  def self.up
    change_column :users, :unsubscribed, :boolean, :null => false, :default => false

    add_column :commits_and_pushes, :errors_json, :string, :limit => 256, :required => false
    add_column :commits_and_pushes, :ignore_errors, :boolean, :default => false, :required => true

    change_column :conflicts, :resolved, :boolean, :null => false, :default => false

    add_column :jira_issues_and_pushes, :errors_json, :string, :limit => 256, :required => false
    add_column :jira_issues_and_pushes, :ignore_errors, :boolean, :default => false, :required => true

    change_column :merges, :successful, :boolean, :null => false, :default => true

    add_index :commits_and_pushes, [:push_id]
    add_index :commits_and_pushes, [:commit_id]

    add_index :jira_issues_and_pushes, [:push_id]
    add_index :jira_issues_and_pushes, [:jira_issue_id]
  end

  def self.down
    change_column :users, :unsubscribed, :boolean, default: false, null: false

    remove_column :commits_and_pushes, :errors_json
    remove_column :commits_and_pushes, :ignore_errors

    change_column :conflicts, :resolved, :boolean, default: false, null: false

    remove_column :jira_issues_and_pushes, :errors_json
    remove_column :jira_issues_and_pushes, :ignore_errors

    change_column :merges, :successful, :boolean, null: false

    remove_index :commits_and_pushes, :name => :index_commits_and_pushes_on_push_id rescue ActiveRecord::StatementInvalid
    remove_index :commits_and_pushes, :name => :index_commits_and_pushes_on_commit_id rescue ActiveRecord::StatementInvalid

    remove_index :jira_issues_and_pushes, :name => :index_jira_issues_and_pushes_on_push_id rescue ActiveRecord::StatementInvalid
    remove_index :jira_issues_and_pushes, :name => :index_jira_issues_and_pushes_on_jira_issue_id rescue ActiveRecord::StatementInvalid
  end
end
