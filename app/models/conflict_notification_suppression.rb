class ConflictNotificationSuppression < ActiveRecord::Base
  fields do
    suppress_until :datetime, null: true
    timestamps
  end

  belongs_to :user, inverse_of: :conflict_notification_suppressions, required: true
  belongs_to :branch, inverse_of: :conflict_notification_suppressions, required: true

  validates :user, uniqueness: { scope: :branch, message: "Conflict suppressions must be unique" }

  scope :by_user, lambda { |user|
    ConflictNotificationSuppression.where(user: user)
  }

  scope :not_expired, lambda { ConflictNotificationSuppression.where('suppress_until IS NULL OR suppress_until >= ?', Time.now) }

  def self.create(user, branch, suppress_until)
    suppression = ConflictNotificationSuppression.where(user: user.id, branch: branch.id).first_or_initialize
    suppression.suppress_until = suppress_until
    suppression.save
    suppression
  end
end
