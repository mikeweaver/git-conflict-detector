class Branch < ActiveRecord::Base
  fields do
    git_tested_at :datetime, null: true
    git_updated_at :datetime, null: false
    name :text, limit: 1024, null: false
    timestamps
  end

  validates :name, uniqueness: true

  belongs_to :author, class_name: User, inverse_of: :branches
  has_many :conflicts, foreign_key: :branch_a, dependent: :destroy

  def self.create_branch_from_git_data(branch_data)
    branch = Branch.where(name: branch_data.name).first_or_initialize
    branch.git_updated_at = branch_data.last_modified_date
    branch.updated_at = Time.now # force updated time
    branch.save
    branch
  end

  def mark_as_tested
    update_column(:git_tested_at, Time.now)
  end

  def create_conflict(conflicting_branch, checked_at_date)
    # if conflict exists, then update the last_tested_date, set last_checked_date to nil
    # otherwise, insert conflict
    x = 5
  end

  def clear_conflict(formerly_conflicting_branch)
    x = 5
  end

  scope :untested_branches, lambda { where("git_tested_at IS ? OR git_updated_at > git_tested_at", nil) }

  scope :branches_not_updated_since, lambda { |checked_at_date| where("updated_at < ?", checked_at_date) }

  def to_s
    name
  end

  def =~(rhs)
    name =~ rhs
  end
end