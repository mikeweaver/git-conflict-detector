class HoboMigration3 < ActiveRecord::Migration
  def self.up
    change_column :branches, :git_updated_at, :datetime, :null => true
  end

  def self.down
    change_column :branches, :git_updated_at, :datetime, null: false
  end
end
