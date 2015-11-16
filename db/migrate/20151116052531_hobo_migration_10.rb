class HoboMigration10 < ActiveRecord::Migration
  def self.up
    create_table :conflict_notification_suppressions do |t|
      t.datetime :suppress_until
      t.datetime :created_at
      t.datetime :updated_at
      t.integer  :user_id
      t.integer  :branch_id
    end
    add_index :conflict_notification_suppressions, [:user_id]
    add_index :conflict_notification_suppressions, [:branch_id]
  end

  def self.down
    drop_table :conflict_notification_suppressions
  end
end
