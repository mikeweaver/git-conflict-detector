class AddCommitsToJiraIssues < ActiveRecord::Migration
  def self.up
    add_column :commits, :jira_issue_id, :integer

    add_index :commits, [:jira_issue_id]
  end

  def self.down
    remove_column :commits, :jira_issue_id

    remove_index :commits, :name => :index_commits_on_jira_issue_id rescue ActiveRecord::StatementInvalid
  end
end
