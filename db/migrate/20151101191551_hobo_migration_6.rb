class HoboMigration6 < ActiveRecord::Migration
  def self.up
    change_column :conflicts, :resolved, :boolean, :null => false, :default => false
  end

  def self.down
    change_column :conflicts, :resolved, :boolean, null: false
  end
end
