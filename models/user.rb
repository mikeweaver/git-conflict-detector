require 'active_record'
require_relative 'branch'

ActiveRecord::Schema.define do
  create_table :users do |table|
    table.column :name, :string, limit: 255, null: false
    table.column :email, :string, limit: 255, null: false
    table.column :created_at, :datetime
    table.column :updated_at, :datetime
  end
end

class User < ActiveRecord::Base
  validates :name, uniqueness: true

  has_many :branches
end
