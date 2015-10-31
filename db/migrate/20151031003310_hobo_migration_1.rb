class HoboMigration1 < ActiveRecord::Migration
  def self.up
    create_table :branches do |t|
      t.datetime :git_tested_at, :null => false
      t.datetime :git_updated_at, :null => false
      t.text     :name, :limit => 1024, :null => false
      t.datetime :created_at
      t.datetime :updated_at
    end

    create_table :conflicts do |t|
      t.boolean  :resolved, :null => false
      t.datetime :last_tested_date, :null => false
      t.datetime :created_at
      t.datetime :updated_at
    end

    create_table :users do |t|
      t.text     :name, :limit => 255, :null => false
      t.text     :email, :limit => 255, :null => false
      t.datetime :created_at
      t.datetime :updated_at
    end
  end

  def self.down
    drop_table :branches
    drop_table :conflicts
    drop_table :users
  end
end
