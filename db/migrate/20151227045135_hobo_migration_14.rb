class HoboMigration14 < ActiveRecord::Migration
  def self.up
    create_table :merges do |t|
      t.datetime :created_at
      t.datetime :updated_at
      t.integer  :source_branch_id
      t.integer  :target_branch_id
      t.boolean  :successful, :null => false
    end
    add_index :merges, [:source_branch_id]
    add_index :merges, [:target_branch_id]
  end

  def self.down
    drop_table :merges
  end
end
