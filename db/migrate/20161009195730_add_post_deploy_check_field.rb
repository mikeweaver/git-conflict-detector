class AddPostDeployCheckField < ActiveRecord::Migration
  def self.up
    add_column :jira_issues, :post_deploy_check_status, :text, :limit => 255, :null => true
    JiraIssue.update_all(post_deploy_check_status: 'Ready to Run')
  end

  def self.down
    remove_column :jira_issues, :post_deploy_check_status
  end
end
