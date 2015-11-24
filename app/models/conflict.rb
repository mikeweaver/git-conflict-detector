class Conflict < ActiveRecord::Base
  fields do
    resolved :boolean, null: false, default: false
    conflicting_files :string, null: false, default: '[]'
    status_last_changed_date :datetime, null: false
    timestamps
  end

  serialize :conflicting_files, JSON

  belongs_to :branch_a, class_name: Branch, inverse_of: :conflicts, required: true
  belongs_to :branch_b, class_name: Branch, inverse_of: :conflicts, required: true

  has_many :conflict_notification_suppressions, dependent: :destroy

  validates :branch_a, :branch_b, presence: true
  validates :branch_a, uniqueness: { scope: :branch_b, message: "Conficts must be unique" }
  validates_each :branch_a do |record, attr, value|
    # specifically ignore nil branches, those will be caught by a different validator
    if (value.present? && record.branch_b.present?) && value.id == record.branch_b.id
      record.errors.add(attr, 'Branch cannot conflict with itself')
    end
  end
  validates_each :conflicting_files do |record, attr, value|
    unless !value.nil? && value.kind_of?(Array)
      record.errors.add(attr, 'must be provided')
    end
  end

  scope :by_branches, lambda { |branch_a, branch_b|
    (branch_a.present? and branch_b.present?) or return nil
    branch_ids = [branch_a.id, branch_b.id]
    Conflict.where(
      'branch_a_id IN (?) AND branch_b_id IN (?) AND branch_a_id <> branch_b_id',
      branch_ids,
      branch_ids)
  }

  scope :by_user, lambda { |user|
    Conflict.joins(:branch_a).joins(:branch_b).where(
      '(branches.author_id = ? OR branch_bs_conflicts.author_id = ?)',
      user.id,
      user.id)
  }

  scope :status_changed_after, lambda { |after_date|
    Conflict.where('status_last_changed_date >= ?', after_date)
  }

  scope :status_changed_before, lambda { |after_date|
    Conflict.where('status_last_changed_date < ?', after_date)
  }

  scope :unresolved, lambda { Conflict.where(resolved: false) }

  scope :resolved, lambda { Conflict.where(resolved: true) }

  scope :exclude_branches_with_ids, lambda { |branch_ids|
    (branch_ids.present? && branch_ids.size > 0) or return Conflict.all
    Conflict.where('(branch_a_id NOT IN (?) AND branch_b_id NOT IN (?))', branch_ids, branch_ids)
  }

  def self.create!(branch_a, branch_b, conflicting_files, checked_at_date)
    conflict = new_conflict(branch_a, branch_b, conflicting_files, checked_at_date)
    conflict.save!
    conflict
  end

  def self.clear!(branch_a, branch_b, checked_at_date)
    conflict = by_branches(branch_a, branch_b).first
    if conflict && !conflict.resolved
      conflict.status_last_changed_date = checked_at_date
      conflict.conflicting_files = []
      conflict.resolved = true
      conflict.save!
    end
  end

  private

  def self.new_conflict(branch_a, branch_b, conflicting_files, checked_at_date)
    conflict = by_branches(branch_a, branch_b).first
    if conflict
      if conflict.resolved || conflict.conflicting_files != conflicting_files
        conflict.status_last_changed_date = checked_at_date
        conflict.conflicting_files = conflicting_files
        conflict.resolved = false
      end
    else
      conflict = new(
          branch_a: branch_a,
          branch_b: branch_b,
          conflicting_files: conflicting_files,
          status_last_changed_date: checked_at_date)
    end
    conflict
  end
end
