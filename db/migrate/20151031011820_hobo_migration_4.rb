class HoboMigration4 < ActiveRecord::Migration
  def self.up


    change_column :branches, :git_tested_at, :datetime, :null => true
    change_column :branches, :git_updated_at, :datetime, :null => false
  end

  def self.down
    change_column :branches, :git_tested_at, :datetime, null: false
    change_column :branches, :git_updated_at, :datetime

  end
end
