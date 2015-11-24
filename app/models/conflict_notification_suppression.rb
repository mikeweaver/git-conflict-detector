class ConflictNotificationSuppression < NotificationSuppression
  belongs_to :conflict, inverse_of: :conflict_notification_suppressions, required: true

  validates :user, uniqueness: { scope: :conflict, message: "Conflict suppressions must be unique" }

  def self.create!(user, conflict, suppress_until)
    suppression = ConflictNotificationSuppression.where(user: user.id, conflict: conflict.id).first_or_initialize
    suppression.suppress_until = suppress_until
    suppression.save!
    suppression
  end
end
