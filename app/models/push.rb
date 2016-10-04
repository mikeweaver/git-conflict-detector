class Push < ActiveRecord::Base
  fields do
    status :string, limit: 32
    timestamps
  end

  validates_inclusion_of :status, :in => Github::Api::Status::STATES.map { |state| state.to_s }

  belongs_to :head_commit, class_name: 'Commit', required: true
  has_many :commits_and_pushes, class_name: :CommitsAndPushes, inverse_of: :push
  has_many :commits, through: :commits_and_pushes
  has_many :jira_issues_and_pushes, class_name: :JiraIssuesAndPushes, inverse_of: :push
  has_many :jira_issues, through: :jira_issues_and_pushes
  belongs_to :branch, inverse_of: :pushes, required: true

  def self.create_from_github_data!(github_data)
    commit = Commit.create_from_github_data!(github_data)
    branch = Branch.create_from_git_data!(github_data.git_branch_data)
    push = Push.where(head_commit: commit, branch: branch).first_or_initialize
    push.status = Github::Api::Status::STATE_PENDING
    push.save!
    CommitsAndPushes.create_or_update!(commit, push)
    push.reload
  end

  scope :from_repository, lambda { |repository_name| joins(:branch).joins(:repository).where("repositories.name = ?", repository_name) }

  scope :with_sha, lambda { |sha| joins(:commit).where(sha: sha) }

  def to_s
    "#{branch.name}/#{head_commit.sha}"
  end

  def has_jira_issues
    jira_issues.any?
  end

  def has_orphan_commits
    orphan_commits.any?
  end

  def orphan_commits
    @orphan_commits ||= commits.orphans
  end

  def <=>(rhs)
    to_s <=> rhs.to_s
  end

  def compute_status!
    self.status = if jira_issues_and_pushes.where('errors_json IS NOT NULL').where(ignore_errors: false).any? ||
        commits_and_pushes.where('errors_json IS NOT NULL').where(ignore_errors: false).any?
      Github::Api::Status::STATE_FAILED
    else
      Github::Api::Status::STATE_SUCCESS
    end
  end
end
