class JiraIssuesAndPushes < ActiveRecord::Base
  include ErrorsJson

  ERROR_WRONG_STATE = 'wrong_state'
  ERROR_NO_COMMITS = 'no_commits'
  ERROR_WRONG_DEPLOY_DATE = 'wrong_deploy_date'

  fields do
    ignore_errors :boolean, default: false, required: true
  end

  belongs_to :push, inverse_of: :jira_issues_and_pushes, required: true
  belongs_to :jira_issue, inverse_of: :jira_issues_and_pushes, required: true

  def self.create_or_update!(jira_issue, push, error_list)
    record = JiraIssuesAndPushes.where(jira_issue: jira_issue, push: push).first_or_initialize
    record.errors = error_list
    record.save!
    record
  end

  scope :unignored_errors, lambda { where('errors_json IS NOT NULL').where(ignore_errors: false) }
end
