class NotificationSuppression < ActiveRecord::Base

  fields do
    suppress_until :datetime, null: true
    timestamps
  end

  belongs_to :user, inverse_of: :notification_suppressions, required: true

  def self.by_user(user)
    where(user: user)
  end

  def self.not_expired
    where('suppress_until IS NULL OR suppress_until >= ?', Time.now)
  end
end
