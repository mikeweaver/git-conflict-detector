class HoboMigration7 < ActiveRecord::Migration
  def self.up
    rename_column :conflicts, :last_tested_date, :status_last_changed_date
    change_column :conflicts, :resolved, :boolean, :null => false, :default => false
  end

  def self.down
    rename_column :conflicts, :status_last_changed_date, :last_tested_date
    change_column :conflicts, :resolved, :boolean, default: false, null: false
  end
end
