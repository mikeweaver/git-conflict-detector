class User < ActiveRecord::Base
  include GitModels::User

  fields do
    unsubscribed :boolean, null: false, default: false
  end

  has_many :notification_suppressions, dependent: :destroy

  def self.create_from_jira_data!(jira_user_data)
    User.where(name: jira_user_data.displayName, email: jira_user_data.emailAddress).first_or_create!
  end

  def self.unsubscribe_by_id!(user_id)
    find_by(id: user_id).unsubscribe!
  end

  def unsubscribe!
    self.unsubscribed = true
    save!
  end

  scope :subscribed_users, lambda {
    User.where(unsubscribed: false)
  }
end
