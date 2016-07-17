class CreatePushesAndCommits < ActiveRecord::Migration
  def self.up
    create_table :pushes do |t|
      t.string   :status, :limit => 32
      t.datetime :created_at
      t.datetime :updated_at
      t.integer  :head_commit_id
      t.integer  :branch_id
    end
    add_index :pushes, [:head_commit_id]
    add_index :pushes, [:branch_id]

    create_table :commits do |t|
      t.text     :sha, :limit => 40, :null => false
      t.text     :message, :limit => 1024, :null => false
      t.datetime :created_at
      t.datetime :updated_at
      t.integer  :author_id
    end
    add_index :commits, [:author_id]

    create_table :commits_and_pushes, :id => false do |t|
      t.integer :commit_id
      t.integer :push_id
    end
  end

  def self.down
    drop_table :pushes
    drop_table :commits
    drop_table :commits_and_pushes
  end
end
