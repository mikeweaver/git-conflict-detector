class HoboMigration11 < ActiveRecord::Migration
  def self.up
    add_column :users, :unsubscribed, :boolean, :null => false, :default => false
  end

  def self.down
    remove_column :users, :unsubscribed
  end
end
