require 'active_record'
require_relative 'user'
require_relative 'conflict'

ActiveRecord::Schema.define do
  create_table :branches do |table|
    table.column :name, :string, limit: 1024, null: false
    table.column :git_updated_at,  :datetime, null: false
    table.column :git_tested_at,  :datetime, null: true
    table.column :created_at, :datetime
    table.column :updated_at, :datetime
  end
end

class Branch < ActiveRecord::Base
  validates :name, uniqueness: true

  has_many :users, as: :authors
  has_many :conflicts

  def create_branch_from_git_data(branch_data)
    branch = Branch.find_or_initialize_by(:name == branch_data.name)
    branch.set!(
        git_updated_at: branch_data.last_modified_date,
        updated_at: Time.now) # force updated time
  end

  def create_conflict(branch_a, branch_b, checked_at_date)
    # if conflict exists, then update the last_tested_date, set last_checked_date to nil
    # otherwise, insert conflict
  end

  def clear_conflict(branch_a, branch_b)
    x = 5
  end

  scope :untested_branches, where(:git_updated_at > :git_tested_at).where(:git_tested_at == nil)

  scope :branches_not_updated_since, lambda |checked_at_date|
    where(:updated_at < checked_at_date)
  end

  def to_s
    @name
  end

  def =~(rhs)
    @name =~ rhs
  end
end
