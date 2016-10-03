class CommitsAndPushes < ActiveRecord::Base
  include ErrorsJson

  ERROR_ORPHAN_NO_JIRA_ISSUE_NUMBER = 'orphan_no_jira_issue_number'
  ERROR_ORPHAN_JIRA_ISSUE_NOT_FOUND = 'orphan_jira_issue_not_found'

  fields do
    ignore_errors :boolean, default: false, required: true
  end

  belongs_to :push, inverse_of: :commits_and_pushes, required: true
  belongs_to :commit, inverse_of: :commits_and_pushes, required: true

  def self.create_or_update!(commit, push, error_list)
    record = CommitsAndPushes.where(commit: commit, push: push).first_or_initialize
    record.errors = error_list
    record.save!
    record
  end
end
