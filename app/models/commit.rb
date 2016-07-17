class Commit < ActiveRecord::Base
  fields do
    sha :text, limit: 40, null: false
    message :text, limit: 1024, null: false
    timestamps
  end

  validates :sha, uniqueness: { message: "SHAs must be globally unique" }
  validates :sha, format: { without: /[0]{40}/ }

  belongs_to :author, class_name: User, inverse_of: :commits, required: true
  has_and_belongs_to_many :pushes, join_table: 'commits_and_pushes'

  def self.create_from_github_data!(github_data)
    commit = Commit.where(sha: github_data.sha).first_or_initialize
    commit.message = github_data.message.truncate(1024)
    commit.author = User.create_from_git_data!(github_data.git_branch_data)
    commit.save!
    commit
  end

  def to_s
    sha
  end

  def <=>(rhs)
    sha <=> rhs.sha
  end
end
