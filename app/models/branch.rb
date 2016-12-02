class Branch < ActiveRecord::Base
  include GitModels::Branch

  fields do
    git_tested_at :datetime, null: true
  end

  has_many :conflicts, foreign_key: :branch_a_id, dependent: :destroy
  has_many :branch_notification_suppressions, dependent: :destroy

  def mark_as_tested!
    update_column(:git_tested_at, Time.current)
  end

  scope :untested_branches, lambda {
    where('branches.git_tested_at IS ? OR branches.git_updated_at > branches.git_tested_at', nil)
  }
end
