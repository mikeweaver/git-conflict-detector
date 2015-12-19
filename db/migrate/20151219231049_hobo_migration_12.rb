class HoboMigration12 < ActiveRecord::Migration
  def self.up
    create_table :notification_suppressions do |t|
      t.datetime :suppress_until
      t.datetime :created_at
      t.datetime :updated_at
      t.integer  :user_id
      t.integer  :branch_id
      t.string   :type
      t.integer  :conflict_id
    end
    add_index :notification_suppressions, [:user_id]
    add_index :notification_suppressions, [:type]
    add_index :notification_suppressions, [:branch_id]
    add_index :notification_suppressions, [:conflict_id]

    drop_table :branch_notification_suppressions
    drop_table :conflict_notification_suppressions
  end

  def self.down
    drop_table :notification_suppressions

    create_table :branch_notification_suppressions do |t|
      t.datetime :suppress_until
      t.datetime :created_at
      t.datetime :updated_at
      t.integer  :user_id
      t.integer  :branch_id
      t.string   :type
      t.integer  :conflict_id
    end
    add_index :branch_notification_suppressions, [:user_id]
    add_index :branch_notification_suppressions, [:type]
    add_index :branch_notification_suppressions, [:branch_id]
    add_index :branch_notification_suppressions, [:conflict_id]

    create_table :conflict_notification_suppressions do |t|
      t.datetime :suppress_until
      t.datetime :created_at
      t.datetime :updated_at
      t.integer  :user_id
      t.integer  :branch_id
      t.string   :type
      t.integer  :conflict_id
    end
    add_index :conflict_notification_suppressions, [:user_id]
    add_index :conflict_notification_suppressions, [:type]
    add_index :conflict_notification_suppressions, [:branch_id]
    add_index :conflict_notification_suppressions, [:conflict_id]
  end
end
