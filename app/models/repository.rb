class Repository < ActiveRecord::Base
  fields do
    name :text, limit: 1024, null: false
    timestamps
  end

  validates :name, uniqueness: true

  has_many :branches, dependent: :destroy

  def self.create!(name)
    branch = Repository.where(name: name).first_or_initialize
    branch.save!
    branch
  end
end
