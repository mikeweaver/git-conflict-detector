module Jira
  module Status
    class PushController < ApplicationController
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

      before_action :find_resources


      def edit
      end

      def update
        jira_issue_keys_to_ignore = []
        commit_shas_to_ignore = []
        if params['push']
          jira_issue_keys_to_ignore = params['push']['jira_issue_keys_to_ignore'] || []
          commit_shas_to_ignore = params['push']['commit_shas_to_ignore'] || []
        end


        updated_record_count = update_ignored_jira_issues(jira_issue_keys_to_ignore) + update_ignored_commits(commit_shas_to_ignore)

        if updated_record_count > 0
          flash[:alert] = 'Push updated, refreshing JIRA and Git data'
          GithubPushHookHandler.new().submit_push_for_processing!(@push)
        elsif params['refresh']
          flash[:alert] = 'Refreshing JIRA and Git data'
          GithubPushHookHandler.new().submit_push_for_processing!(@push)
        else
          flash[:alert] = 'No changes made'
        end
        redirect_to action: 'edit', id: @push.head_commit.sha
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

      private

      def find_resources
        @push = Push.joins(:head_commit).where('commits.sha = ?', params[:id]).first!
      rescue ActiveRecord::RecordNotFound => e
        flash[:alert] = 'The push could not be found'
        redirect_to controller: '/errors', action: 'bad_request'
      end

      def update_ignored_jira_issues(jira_issue_keys_to_ignore)
        updated_record_count = 0
        @push.jira_issues_and_pushes.each do |jira_issue_and_push|
          jira_issue_and_push.ignore_errors = jira_issue_keys_to_ignore.include?(jira_issue_and_push.jira_issue.key)
          updated_record_count += 1 if jira_issue_and_push.changed?
          jira_issue_and_push.save!
        end
        updated_record_count
      end

      def update_ignored_commits(commit_shas_to_ignore)
        updated_record_count = 0
        @push.commits_and_pushes.each do |commit_and_push|
          commit_and_push.ignore_errors = commit_shas_to_ignore.include?(commit_and_push.commit.sha)
          updated_record_count += 1 if commit_and_push.changed?
          commit_and_push.save!
        end
        updated_record_count
      end
    end
  end
end

