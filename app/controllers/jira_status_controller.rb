class JiraStatusController < ApplicationController
  def show_status_for_commit
    @push = Push.joins(:head_commit).where('commits.sha = ?', params[:sha]).first
  rescue ActiveRecord::RecordNotFound => e
    flash[:alert] = 'The commit could not be found'
    redirect_to controller: 'errors', action: 'bad_request'
  end

  def should_ignore_commit_errors(commit)
    record = commit.commits_and_pushes.where(push: @push).first
    record.errors.empty? || record.ignore_errors
  end
  helper_method :should_ignore_commit_errors

  def github_url_for_commit(commit)
    "https://github.com/#{@push.branch.repository.name}/commit/#{commit.sha}"
  end
  helper_method :github_url_for_commit

  def jira_url_for_issue(jira_issue)
    "#{GlobalSettings.jira.site}/browse/#{jira_issue.key}"
  end
  helper_method :jira_url_for_issue
end
