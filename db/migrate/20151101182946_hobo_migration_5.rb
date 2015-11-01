class HoboMigration5 < ActiveRecord::Migration
  def self.up
    drop_table :user_branches
  end

  def self.down
    create_table "user_branches", id: false, force: :cascade do |t|
      t.integer "branch_id"
      t.integer "user_id"
    end
  end
end
