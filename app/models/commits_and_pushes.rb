class CommitsAndPushes < ActiveRecord::Base
  include ErrorsJson

  ERROR_ORPHAN_NO_JIRA_ISSUE_NUMBER = 'orphan_no_jira_issue_number'
  ERROR_ORPHAN_JIRA_ISSUE_NOT_FOUND = 'orphan_jira_issue_not_found'

  belongs_to :push, inverse_of: :commits_and_pushes, required: true
  belongs_to :commit, inverse_of: :commits_and_pushes, required: true

  scope :for_push, lambda { |push| where(push: push) }

  def self.create_or_update!(commit, push, error_list=nil)
    record = CommitsAndPushes.where(commit: commit, push: push).first_or_initialize
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

  def self.destroy_if_commit_not_in_list(push, commits)
    if commits.any?
      for_push(push).where('commit_id NOT IN (?)', commits).destroy_all
    else
      for_push(push).destroy_all
    end
  end
end
