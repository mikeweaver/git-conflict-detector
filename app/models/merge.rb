class Merge < ActiveRecord::Base
  fields do
    timestamps
    successful :boolean, null: false, default: true
  end

  belongs_to :source_branch, class_name: Branch, required: true
  belongs_to :target_branch, class_name: Branch, required: true
  has_one :repository, through: :target_branch

  validates :source_branch, :target_branch, presence: true
  validates :source_branch, uniqueness: { scope: :target_branch, message: "Merges must be unique" }
  validates_each :source_branch do |record, attr, value|
    # specifically ignore nil branches, those will be caught by a different validator
    if (value.present? && record.target_branch.present?)
      if value.id == record.target_branch.id
        record.errors.add(attr, 'Branch cannot merge with itself')
      end
      if value.repository.id != record.target_branch.repository.id
        record.errors.add(attr, 'Branches from different repositories cannot be merged')
      end
    end
  end

  scope :by_target_user, lambda { |user|
    joins(:target_branch).where(
      "(branches.author_id = ?)",
      user.id)
  }

  scope :created_after, lambda { |after_date|
    where('merges.created_at >= ?', after_date)
  }

  scope :successful, lambda { where(successful: true) }

  scope :unsuccessful, lambda { where(successful: false) }

  scope :from_repository, lambda { |repository_name| joins(:repository).where("repositories.name = ?", repository_name) }
end
