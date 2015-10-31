class Conflict < ActiveRecord::Base
  fields do
    resolved :boolean, null: false
    last_tested_date :datetime, null: false
    timestamps
  end

  belongs_to :branch_a, class_name: Branch, inverse_of: :conflicts
  belongs_to :branch_b, class_name: Branch, inverse_of: :conflicts
end
