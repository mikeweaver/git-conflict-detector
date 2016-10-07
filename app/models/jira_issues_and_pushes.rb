class JiraIssuesAndPushes < ActiveRecord::Base
  include ErrorsJson

  ERROR_WRONG_STATE = 'wrong_state'
  ERROR_NO_COMMITS = 'no_commits'
  ERROR_WRONG_DEPLOY_DATE = 'wrong_deploy_date'
  ERROR_NO_DEPLOY_DATE = 'no_deploy_date'

  belongs_to :push, inverse_of: :jira_issues_and_pushes, required: true
  belongs_to :jira_issue, inverse_of: :jira_issues_and_pushes, required: true

  scope :for_push, lambda { |push| where(push: push) }

  def self.create_or_update!(jira_issue, push, error_list=nil)
    record = JiraIssuesAndPushes.where(jira_issue: jira_issue, push: push).first_or_initialize
    # preserve existing errors if not specified
    if error_list
      record.error_list = error_list
    end
    # if this is a newly created relationship, copy the ignore flag from the most recent relationship
    unless record.id
      record.copy_ignore_flag_from_most_recent_push
    end
    record.save!
    record
  end

  def self.get_error_counts_for_push(push)
    get_error_counts(with_unignored_errors.for_push(push))
  end

  def self.destroy_if_jira_issue_not_in_list(push, jira_issues)
    if jira_issues.any?
      for_push(push).where('jira_issue_id NOT IN (?)', jira_issues).destroy_all
    else
      for_push(push).destroy_all
    end
  end

  def copy_ignore_flag_from_most_recent_push
    if previous_record = JiraIssuesAndPushes.where(jira_issue: self.jira_issue).where.not(id: self.id).order('id desc').first
      self.ignore_errors = previous_record.ignore_errors
    end
  end
end
