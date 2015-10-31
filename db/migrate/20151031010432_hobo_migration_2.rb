class HoboMigration2 < ActiveRecord::Migration
  def self.up
    create_table :user_branches, :id => false do |t|
      t.integer :branch_id
      t.integer :user_id
    end

    add_column :branches, :author_id, :integer

    add_column :conflicts, :branch_a_id, :integer
    add_column :conflicts, :branch_b_id, :integer

    add_index :branches, [:author_id]

    add_index :conflicts, [:branch_a_id]
    add_index :conflicts, [:branch_b_id]
  end

  def self.down
    remove_column :branches, :author_id

    remove_column :conflicts, :branch_a_id
    remove_column :conflicts, :branch_b_id

    drop_table :user_branches

    remove_index :branches, :name => :index_branches_on_author_id rescue ActiveRecord::StatementInvalid

    remove_index :conflicts, :name => :index_conflicts_on_branch_a_id rescue ActiveRecord::StatementInvalid
    remove_index :conflicts, :name => :index_conflicts_on_branch_b_id rescue ActiveRecord::StatementInvalid
  end
end
