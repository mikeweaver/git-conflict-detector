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

  def conflicting_files_excluding(files_to_exclude)
    conflicting_files.reject do |file|
      files_to_exclude.any? do |file_to_exclude|
        file =~ Regexp.new(file_to_exclude)
      end
    end
  end

  def conflicting_files_including(files_to_include)
    conflicting_files.select do |file|
      files_to_include.any? do |file_to_include|
        file =~ Regexp.new(file_to_include)
      end
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

  scope :exclude_non_self_conflicting_authored_branches_with_ids, lambda { |user, branch_ids|
     # exclude branches that were authored by the user but do NOT conflict with another
     # branch from the same user
     (branch_ids.present? && branch_ids.size > 0) or return Conflict.all
     Conflict.joins(:branch_a).joins(:branch_b).where(
         'NOT (((branch_a_id IN (?) AND branches.author_id = ?) OR (branch_b_id IN (?) AND branch_bs_conflicts.author_id = ?)) AND branches.author_id <> branch_bs_conflicts.author_id)',
         branch_ids,
         user.id,
         branch_ids,
         user.id)
  }

  def self.create!(branch_a, branch_b, conflicting_files, checked_at_date)
    conflict = new_conflict(branch_a, branch_b, conflicting_files, checked_at_date)
    conflict.save!
    conflict
  end

  def self.resolve!(branch_a, branch_b, checked_at_date)
    conflict = by_branches(branch_a, branch_b).first
    if conflict
      conflict.resolve!(checked_at_date)
    end
  end

  def resolve!(checked_at_date)
    unless self.resolved
      self.status_last_changed_date = checked_at_date
      self.conflicting_files = []
      self.resolved = true
      save!
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
