class User < ActiveRecord::Base
  fields do
    name :text, limit: 255, null: false
    email :text, limit: 255, null: false
    unsubscribed :boolean, null: false, default: false
    timestamps
  end

  validates :name, :uniqueness => {:scope => :email}
  
  has_many :branches, foreign_key: "author_id"
  has_many :commits, foreign_key: "author_id"
  has_many :notification_suppressions, dependent: :destroy

  def self.create_from_git_data!(branch_data)
    User.where(name: branch_data.author_name, email: branch_data.author_email).first_or_create!
  end

  def self.users_with_emails(email_filter_list)
    # if filter is empty, return all users, otherwise only return users whose emails are in the list
    User.all.select { |user| email_filter_list.empty? || email_filter_list.include?(user.email.downcase) }
  end

  def self.unsubscribe_by_id!(user_id)
    User.where(id: user_id).first.unsubscribe!
  end

  def unsubscribe!
    self.unsubscribed = true
    save!
  end

  scope :subscribed_users, lambda {
    User.where(unsubscribed: false)
  }
end
