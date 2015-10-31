class User < ActiveRecord::Base
  fields do
    name :text, limit: 255, null: false
    email :text, limit: 255, null: false
    timestamps
  end

  validates :name, uniqueness: true

  has_and_belongs_to_many :branches, join_table: :user_branches
end
