class BranchNotificationSuppression < NotificationSuppression
  belongs_to :branch, inverse_of: :branch_notification_suppressions, required: true

  validates :user, uniqueness: { scope: :branch, message: "Branch suppressions must be unique" }

  def self.create!(user, branch, suppress_until)
    suppression = BranchNotificationSuppression.where(user: user.id, branch: branch.id).first_or_initialize
    suppression.suppress_until = suppress_until
    suppression.save!
    suppression
  end
end
