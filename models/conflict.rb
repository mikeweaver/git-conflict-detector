require 'active_record'
require_relative 'branch'

ActiveRecord::Schema.define do
  create_table :conflicts do |table|
    table.column :last_tested_date,  :datetime, null: false
    table.column :resolved, :boolean, null: false
    table.column :created_at, :datetime
    table.column :updated_at, :datetime
  end
end

class Conflict < ActiveRecord::Base
  has_one :branch, as: :branch_a
  has_one :branch, as: :branch_b
end
