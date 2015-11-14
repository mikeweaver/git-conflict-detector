class HoboMigration9 < ActiveRecord::Migration
  def self.up
    change_column :conflicts, :resolved, :boolean, :null => false, :default => false
    change_column :conflicts, :conflicting_files, :string, :null => false, :default => "[]"
  end

  def self.down
    change_column :conflicts, :resolved, :boolean, default: false,      null: false
    change_column :conflicts, :conflicting_files, :string, default: "--- []\n", null: false
  end
end
