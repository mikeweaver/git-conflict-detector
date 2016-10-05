class JiraStatusController < ApplicationController
  ERROR_CODE_MAP = {
      'commit' => {
          CommitsAndPushes::ERROR_ORPHAN_NO_JIRA_ISSUE_NUMBER.to_s => "Commit(s) with no JIRA issue number",
          CommitsAndPushes::ERROR_ORPHAN_JIRA_ISSUE_NOT_FOUND.to_s => "Commit(s) with an unknown JIRA issue number"
      },
      'jira_issue' => {
          JiraIssuesAndPushes::ERROR_WRONG_STATE.to_s => "JIRA issue(s) in the wrong state",
          JiraIssuesAndPushes::ERROR_NO_COMMITS.to_s => "JIRA issue(s) with no commits",
          JiraIssuesAndPushes::ERROR_WRONG_DEPLOY_DATE.to_s => "JIRA issue(s) with a deploy date in the past",
          JiraIssuesAndPushes::ERROR_NO_DEPLOY_DATE.to_s => "JIRA issue(s) with no deploy date"
      }
  }

  def show_status_for_commit
    @push = Push.joins(:head_commit).where('commits.sha = ?', params[:sha]).first
  rescue ActiveRecord::RecordNotFound => e
    flash[:alert] = 'The commit could not be found'
    redirect_to controller: 'errors', action: 'bad_request'
  end

  def github_url_for_commit(commit)
    "https://github.com/#{@push.branch.repository.name}/commit/#{commit.sha}"
  end
  helper_method :github_url_for_commit

  def jira_url_for_issue(jira_issue)
    "#{GlobalSettings.jira.site}/browse/#{jira_issue.key}"
  end
  helper_method :jira_url_for_issue

  def get_combined_error_counts
    error_counts = {}
    error_counts['jira_issue'] = JiraIssuesAndPushes.get_error_counts_for_push(@push)
    error_counts['commit'] = CommitsAndPushes.get_error_counts_for_push(@push)
    error_counts
  end
  helper_method :get_combined_error_counts

  def map_error_code_to_message(error_object, error_code)
    ERROR_CODE_MAP[error_object][error_code]
  end
  helper_method :map_error_code_to_message
end
