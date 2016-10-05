class Commit < ActiveRecord::Base
  fields do
    sha :text, limit: 40, null: false
    message :text, limit: 1024, null: false
    timestamps
  end

  validates :sha, uniqueness: { message: "SHAs must be globally unique" }
  validates :sha, format: { without: /[0]{40}/ }

  belongs_to :author, class_name: User, inverse_of: :commits, required: true
  belongs_to :jira_issue, class_name: JiraIssue, inverse_of: :commits, required: false

  has_many :commits_and_pushes, class_name: :CommitsAndPushes, inverse_of: :commit
  has_many :pushes, through: :commits_and_pushes

  def self.create_from_github_data!(github_data)
    commit = Commit.where(sha: github_data.sha).first_or_initialize
    commit.message = github_data.message.truncate(1024)
    commit.author = User.create_from_git_data!(github_data.git_branch_data)
    commit.save!
    commit
  end

  def self.create_from_git_commit!(git_commit)
    commit = Commit.where(sha: git_commit.sha).first_or_initialize
    commit.message = git_commit.message.truncate(1024)
    commit.author = User.create_from_git_data!(git_commit)
    commit.save!
    commit
  end

  scope :orphans, lambda { where(jira_issue_id: nil) }

  def short_sha
    sha[0,7]
  end

  def to_s
    sha
  end

  def <=>(rhs)
    sha <=> rhs.sha
  end

  def has_unignored_errors?(push)
    commits_and_pushes.where(push: push).unignored_errors.any?
  end
end
