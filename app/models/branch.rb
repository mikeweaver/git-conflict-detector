class Branch < ActiveRecord::Base
  fields do
    git_tested_at :datetime, null: true
    git_updated_at :datetime, null: false
    name :text, limit: 1024, null: false
    timestamps
  end

  validates :name, uniqueness: { scope: :repository, message: 'Branch names must be unique within each repository' }

  belongs_to :author, class_name: User, inverse_of: :branches, required: true
  belongs_to :repository, inverse_of: :branches, required: true
  has_many :conflicts, foreign_key: :branch_a_id, dependent: :destroy
  has_many :branch_notification_suppressions, dependent: :destroy
  has_many :pushes, class_name: Push, dependent: :destroy

  def self.create_from_git_data!(branch_data)
    repository = Repository.create!(branch_data.repository_name)
    branch = Branch.where(repository: repository, name: branch_data.name).first_or_initialize
    branch.git_updated_at = branch_data.last_modified_date
    branch.updated_at = Time.current # force updated time
    branch.author = User.create_from_git_data!(branch_data)
    branch.save!
    branch
  end

  def mark_as_tested!
    update_column(:git_tested_at, Time.current)
  end

  scope :untested_branches, lambda {
    where('branches.git_tested_at IS ? OR branches.git_updated_at > branches.git_tested_at', nil)
  }

  scope :branches_not_updated_since, lambda { |checked_at_date| where('branches.updated_at < ?', checked_at_date) }

  scope :from_repository, lambda { |repository_name|
    joins(:repository).where('repositories.name = ?', repository_name)
  }

  scope :with_name, lambda { |name| where(name: name) }

  def to_s
    name
  end

  def =~(other) # rubocop:disable Rails/Delegate
    name =~ other
  end

  def <=>(other)
    name <=> other.name
  end
end
