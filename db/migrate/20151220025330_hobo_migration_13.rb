class HoboMigration13 < ActiveRecord::Migration
  def self.up
    create_table :repositories do |t|
      t.text     :name, :limit => 1024, :null => false
      t.datetime :created_at
      t.datetime :updated_at
    end

    add_column :branches, :repository_id, :integer

    add_index :branches, [:repository_id]
  end

  def self.down
    remove_column :branches, :repository_id

    drop_table :repositories

    remove_index :branches, :name => :index_branches_on_repository_id rescue ActiveRecord::StatementInvalid
  end
end
