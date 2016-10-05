class PushManager
  VALID_JIRA_STATUSES = ['Ready to Deploy']

  class << self
    # TODO move all of this to the push model?
    def process_push(push)
      # clone repo
      git = Git::Git.new(push.branch.repository.name)
      # diff with master to get list of commits
      # TODO extract into a function
      commits = git.commit_diff_refs(push.head_commit.sha, ancestor_branch, fetch: true).collect do |git_commit|
        unless git_commit.message.match(commit_messages_to_ignore)
          Commit.create_from_git_commit!(git_commit)
        end
      end.compact

      # get ticket numbers from commits
      ticket_numbers = extract_jira_issue_keys(commits)

      # lookup tickets in JIRA
      # TODO break up into two functions
      jira_issues = get_jira_issues!(ticket_numbers)

      # TODO extract into a function
      jira_issues.each do |jira_issue|
        commits.each do |commit|
          if extract_jira_issue_key(commit) == jira_issue.key
            jira_issue.commits << commit
          end
        end
        jira_issue.save!
      end

      # TODO extract into a function
      jira_issues.each do |jira_issue|
        errors = []
        if VALID_JIRA_STATUSES.exclude?(jira_issue.status)
          errors << JiraIssuesAndPushes::ERROR_WRONG_STATE
        end

        if jira_issue.commits.empty?
          errors << JiraIssuesAndPushes::ERROR_NO_COMMITS
        end

        if jira_issue.targeted_deploy_date
          if jira_issue.targeted_deploy_date.to_date < Date.today
            errors << JiraIssuesAndPushes::ERROR_WRONG_DEPLOY_DATE
          end
        else
          errors << JiraIssuesAndPushes::ERROR_NO_DEPLOY_DATE
        end

        JiraIssuesAndPushes.create_or_update!(jira_issue, push, errors)
      end
      # destroy relationship to issues that are no longer in the push
      JiraIssuesAndPushes.destroy_if_jira_issue_not_in_list(push, jira_issues)

      # TODO extract into a function
      commits.each do |commit|
        commit.reload
        errors = []
        unless commit.jira_issue
          if commit.message.match(jira_issue_regex)
            errors << CommitsAndPushes::ERROR_ORPHAN_JIRA_ISSUE_NOT_FOUND
          else
            errors << CommitsAndPushes::ERROR_ORPHAN_NO_JIRA_ISSUE_NUMBER
          end
        end

        CommitsAndPushes.create_or_update!(commit, push, errors)
      end
      # destroy relationship to commits that are no longer in the push
      CommitsAndPushes.destroy_if_commit_not_in_list(push, commits)

      push.reload

      # compute status
      push.compute_status!
      push.save!
      push.status
    end

    def ancestor_branch
      'production' # TODO move to setting
    end

    def jira_project_keys
      ['STORY', 'TECH', 'WEB', 'OPS'] # TODO move to setting
    end

    def jira_issue_regex
      /(?:^|\s|\/|_|-)((?:#{jira_project_keys.join('|')})[- _]\d+)/i
    end

    def commit_messages_to_ignore
      /(^|\s)merge($|\s)/i # TODO move to setting
    end

    def extract_jira_issue_keys(commits)
      commits.collect do |commit|
        extract_jira_issue_key(commit)
      end.compact.uniq
    end

    def extract_jira_issue_key(commit)
      if match = commit.message.match(jira_issue_regex)
        match.captures[0].upcase
      end
    end

    def commits_without_a_jira_issue_key!(commits)
      commits.collect do |commit|
        unless commit.message.match(jira_issue_regex)
          Commit.create_from_git_commit!(commit)
        end
      end.compact
    end

    def get_jira_issues!(ticket_numbers)
      jira_client = JIRA::ClientWrapper.new(GlobalSettings.jira)
      ticket_numbers.collect do |ticket_number|
        # TODO: get parents of sub-tasks
        JiraIssue.create_from_jira_data!(jira_client.find_issue(ticket_number))
      end.compact
    end

    def compute_push_status(branch_name, orphan_commits, ticket_numbers, jira_issues)
      if jira_issues_with_invalid_statuses(jira_issues) ||
          ticket_numbers_not_in_jira_issue_list(ticket_numbers, jira_issues).any? ||
          (orphan_commits && !ignore_orphan_commits_for_branches.includes?(branch_name))
        Github::Api::Status::STATE_FAILED
      else
        Github::Api::Status::STATE_SUCCESS
      end
    end

    def jira_issues_with_invalid_statuses(jira_issues)
      jira_issues.reject do |jira_issue|
        VALID_JIRA_STATUSES.include?(jira_issue.status)
      end
    end

    def ticket_numbers_not_in_jira_issue_list(ticket_numbers, jira_issues)
      jira_issue_numbers = jira_issues.collect do |jira_issue|
        jira_issue.key
      end
      ticket_numbers - jira_issue_numbers
    end
  end
end
