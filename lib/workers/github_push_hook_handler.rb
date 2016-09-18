class GithubPushHookHandler
  PENDING_QUEUE = 'pending'
  PROCESSING_QUEUE = 'processing'
  CONTEXT_NAME = 'JIRA Checker'
  STATE_DESCRIPTIONS = {
      Github::Api::Status::STATE_PENDING => 'Branch is being examined',
      Github::Api::Status::STATE_SUCCESS => 'Branch is OK',
      Github::Api::Status::STATE_FAILED => 'Branch was rejected'
  }
  VALID_JIRA_STATUSES = ['Ready to Deploy']

  def initialize(push_hook_payload)
    @payload = Github::Api::PushHookPayload.new(push_hook_payload)

  end

  def queue!
    Rails.logger.info('Queueing request')
    Rails.logger.info(@payload)
    set_status_for_repo!(Github::Api::Status::STATE_PENDING, STATE_DESCRIPTIONS[Github::Api::Status::STATE_PENDING])
    process!
  end
  handle_asynchronously(:queue!, queue: PENDING_QUEUE)

  def process!
    Rails.logger.info('Processing request')
    status = handle_process_request!
    set_status_for_repo!(status, STATE_DESCRIPTIONS[status])
  end
  handle_asynchronously(:process!, queue: PROCESSING_QUEUE)

  private

  def handle_process_request!
    push = Push.create_from_github_data!(@payload)
    # clone repo
    git = Git::Git.new(@payload.repository_path)
    # diff with master to get list of commits
    git_commits = git.commits_diff_branch_with_ancestor(@payload.branch_name, ancestor_branch)
    # get ticket numbers from commits
    ticket_numbers = extract_jira_issue_keys(git_commits)
    # lookup tickets in JIRA
    jira_issues = get_jira_issues!(ticket_numbers)
    # get list of orphaned commits
    orphan_commits = commits_without_a_jira_issue_key!(git_commits)
    # compute status
    push.status = compute_push_status(@payload.branch_name, orphan_commits, ticket_numbers, jira_issues)
    push.save!
    push.status
  end

  def set_status_for_repo!(state, description)
    api = Github::Api::Status.new(Rails.application.secrets.github_user_name,
                                  Rails.application.secrets.github_password)
    api.set_status(@payload.repository_owner_name,
                   @payload.repository_name,
                   @payload.sha,
                   CONTEXT_NAME,
                   state,
                   description,
                   'http://moreinfohere.com')
  end

  def ancestor_branch
    'master' # TODO move to setting
  end

  def jira_project_keys
    ['STORY', 'TECH', 'WEB'] # TODO move to setting
  end

  def jira_issue_regex
    /(?:^|\s)((?:#{jira_project_keys.join('|')})[- _]\d+)/
  end

  def extract_jira_issue_keys(commits)
    commits.collect do |commit|
      if match = commit.message.match(jira_issue_regex)
        match.captures[0]
      end
    end.compact.uniq
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
      # TODO construct JIRA issue models
      jira_client.find_issue(ticket_number)
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
      VALID_JIRA_STATUSES.include?(jira_issue.fields['status']['name'])
    end
  end

  def ticket_numbers_not_in_jira_issue_list(ticket_numbers, jira_issues)
    jira_issue_numbers = jira_issues.collect do |jira_issue|
      jira_issue.key
    end
    ticket_numbers - jira_issue_numbers
  end
end
