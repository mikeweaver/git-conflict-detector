class PushManager
  class << self
    def process_push!(push)
      push.status = Github::Api::Status::STATE_PENDING
      push.save!

      commits = get_commits_from_push(push)

      # get issue keys from commits
      issue_keys = extract_jira_issue_keys(commits)

      # lookup issues in JIRA
      jira_issues = get_jira_issues!(issue_keys)

      # get issues from JIRA that should have been in the commits, but were not
      jira_issues += get_other_jira_issues_in_valid_states(issue_keys)

      link_commits_to_jira_issues(jira_issues, commits)

      link_jira_issues_to_push_and_detect_errors(push, jira_issues)

      # destroy relationship to issues that are no longer in the push
      JiraIssuesAndPushes.destroy_if_jira_issue_not_in_list(push, jira_issues)

      link_commits_to_push_and_detect_errors(push, commits)

      # destroy relationship to commits that are no longer in the push
      CommitsAndPushes.destroy_if_commit_not_in_list(push, commits)

      push.reload

      # compute status
      push.compute_status!
      push.save!
      push
    end

    def ancestor_branch_name(branch_name)
      GlobalSettings.jira.ancestor_branches[branch_name] || GlobalSettings.jira.ancestor_branches['default']
    end

    private

    def jira_issue_regexp
      /(?:^|\s|\/|_|-)((?:#{GlobalSettings.jira.project_keys.join('|')})[- _]\d+)/i
    end

    def valid_jira_state?(status)
      GlobalSettings.jira.valid_statuses.any? { |valid_status| valid_status.casecmp(status) == 0 }
    end

    def valid_post_deploy_check_status?(status)
      if status
        GlobalSettings.jira.valid_post_deploy_check_statuses.any? { |valid_status| valid_status.casecmp(status) == 0 }
      else
        false
      end
    end

    def extract_jira_issue_keys(commits)
      commits.collect do |commit|
        extract_jira_issue_key(commit)
      end.compact.uniq
    end

    def extract_jira_issue_key(commit)
      match = commit.message.match(jira_issue_regexp)
      if match
        match.captures[0].upcase.sub(/[ _]/, '-')
      end
    end

    def get_jira_issues!(issue_keys)
      jira_client = JIRA::ClientWrapper.new(Rails.application.secrets.jira)
      issue_keys.collect do |ticket_number|
        issue = jira_client.find_issue_by_key(ticket_number)
        if issue
          JiraIssue.create_from_jira_data!(issue)
        end
      end.compact
    end

    def get_other_jira_issues_in_valid_states(issue_keys)
      quoted_statuses = GlobalSettings.jira.valid_statuses.map do |status|
        "\"#{status}\""
      end
      jql = "status IN (#{quoted_statuses.join(', ')}) " \
            "AND project IN (#{GlobalSettings.jira.project_keys.join(', ').upcase})"

      if issue_keys.any?
        jql += " AND key NOT IN (#{issue_keys.join(', ')})"
      end
      jira_client = JIRA::ClientWrapper.new(Rails.application.secrets.jira)
      jira_client.find_issues_by_jql(jql).collect do |issue|
        JiraIssue.create_from_jira_data!(issue)
      end.compact
    end

    def link_commits_to_jira_issues(jira_issues, commits)
      jira_issues.each do |jira_issue|
        commits.each do |commit|
          if extract_jira_issue_key(commit) == jira_issue.key
            jira_issue.commits << commit
          end
        end
        jira_issue.save!
      end
    end

    def link_jira_issues_to_push_and_detect_errors(push, jira_issues)
      jira_issues.each do |jira_issue|
        JiraIssuesAndPushes.create_or_update!(jira_issue, push, detect_errors_for_jira_issue(jira_issue))
      end
    end

    def detect_errors_for_jira_issue(jira_issue)
      errors = []
      unless valid_jira_state?(jira_issue.status)
        errors << JiraIssuesAndPushes::ERROR_WRONG_STATE
      end

      unless valid_post_deploy_check_status?(jira_issue.post_deploy_check_status)
        errors << JiraIssuesAndPushes::ERROR_POST_DEPLOY_CHECK_STATUS
      end

      if jira_issue.commits.empty?
        errors << JiraIssuesAndPushes::ERROR_NO_COMMITS
      end

      if jira_issue.targeted_deploy_date
        if jira_issue.targeted_deploy_date.to_date < Time.zone.today
          errors << JiraIssuesAndPushes::ERROR_WRONG_DEPLOY_DATE
        end
      else
        errors << JiraIssuesAndPushes::ERROR_NO_DEPLOY_DATE
      end
      errors
    end

    def link_commits_to_push_and_detect_errors(push, commits)
      commits.each do |commit|
        # need to reload to determine if we have a JIRA issue or not
        # TODO: try commit.jira_issue(true) to force a reload instead
        commit.reload
        CommitsAndPushes.create_or_update!(commit, push, detect_errors_for_commit(commit))
      end
    end

    def detect_errors_for_commit(commit)
      errors = []
      unless commit.jira_issue
        errors << if commit.message.match(jira_issue_regexp)
                    CommitsAndPushes::ERROR_ORPHAN_JIRA_ISSUE_NOT_FOUND
                  else
                    CommitsAndPushes::ERROR_ORPHAN_NO_JIRA_ISSUE_NUMBER
                  end
      end
    end

    def get_commits_from_push(push)
      git = Git::Git.new(push.branch.repository.name)
      git.clone_repository(GlobalSettings.jira.ancestor_branches['default'])
      git.commit_diff_refs(
        push.head_commit.sha,
        ancestor_branch_name(push.branch.name),
        fetch: true
      ).collect do |git_commit|
        next if GlobalSettings.jira.ignore_commits_with_messages.include_regexp?(
          git_commit.message,
          regexp_options: Regexp::IGNORECASE
        )
        Commit.create_from_git_commit!(git_commit)
      end.compact
    end
  end
end
