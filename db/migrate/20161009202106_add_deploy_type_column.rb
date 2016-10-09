class AddDeployTypeColumn < ActiveRecord::Migration
  def self.up
    add_column :jira_issues, :deploy_type, :text, :limit => 255
  end

  def self.down
    remove_column :jira_issues, :deploy_type
  end
end
