class JiraIssuesAndPushes < ActiveRecord::Base
  include ErrorsJson

  ERROR_WRONG_STATE = 'wrong_state'
  ERROR_NO_COMMITS = 'no_commits'
  ERROR_WRONG_DEPLOY_DATE = 'wrong_deploy_date'
  ERROR_NO_DEPLOY_DATE = 'no_deploy_date'

  fields do

  end

  belongs_to :push, inverse_of: :jira_issues_and_pushes, required: true
  belongs_to :jira_issue, inverse_of: :jira_issues_and_pushes, required: true

  def self.create_or_update!(jira_issue, push, error_list=nil)
    record = JiraIssuesAndPushes.where(jira_issue: jira_issue, push: push).first_or_initialize
    # preserve existing errors if not specified
    if error_list
      record.error_list = error_list
    end
    record.save!
    record
  end

  def self.get_error_counts_for_push(push)
    get_error_counts(unignored_errors.where(push: push))
  end
end
