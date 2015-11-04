class Conflict < ActiveRecord::Base
  fields do
    resolved :boolean, null: false, default: false
    status_last_changed_date :datetime, null: false
    timestamps
  end

  belongs_to :branch_a, class_name: Branch, inverse_of: :conflicts, required: true
  belongs_to :branch_b, class_name: Branch, inverse_of: :conflicts, required: true

  validates :branch_a, :branch_b, presence: true
  validates_each :branch_a do |record, attr, value|
    # specifically ignore nil branches, those will be caught by a different validator
    if (value.present? and record.branch_b.present?) && value.id == record.branch_b.id
      record.errors.add(attr, 'Branch cannot conflict with itself')
    end
  end

  scope :conflict_by_branches, lambda { |branch_a, branch_b|
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

  def self.create(branch_a, branch_b, checked_at_date)
    conflict = new_conflict(branch_a, branch_b, checked_at_date)
    conflict.save
  end

  def self.create!(branch_a, branch_b, checked_at_date)
    conflict = new_conflict(branch_a, branch_b, checked_at_date)
    conflict.save!
  end

  def self.clear!(branch_a, branch_b, checked_at_date)
    conflict = conflict_by_branches(branch_a, branch_b).first
    if conflict && !conflict.resolved
      conflict.status_last_changed_date = checked_at_date
      conflict.resolved = true
      conflict.save!
    end
  end

  private

  def self.new_conflict(branch_a, branch_b, checked_at_date)
    conflict = conflict_by_branches(branch_a, branch_b).first
    if conflict
      if conflict.resolved
        conflict.status_last_changed_date = checked_at_date
        conflict.resolved = false
      end
    else
      conflict = new(branch_a: branch_a, branch_b: branch_b, status_last_changed_date: checked_at_date)
    end
    conflict
  end
end
