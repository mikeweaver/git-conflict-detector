class HoboMigration8 < ActiveRecord::Migration
  def self.up
    add_column :conflicts, :conflicting_files, :string, :null => false, :default => []
    change_column :conflicts, :resolved, :boolean, :null => false, :default => false
  end

  def self.down
    remove_column :conflicts, :conflicting_files
    change_column :conflicts, :resolved, :boolean, default: false, null: false
  end
end
