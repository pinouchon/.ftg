class CreateTasks < ActiveRecord::Migration
  def up
    create_table :tasks do |t|
      t.date :day
      t.string :name
      t.datetime :synced_at
      t.datetime :edited_at
      t.datetime :deleted_at
      t.integer :duration
      t.integer :toggl_activity_id
      t.timestamps
    end
    puts 'Migrating up'
  end

  def down
    drop_table :tasks
    puts 'Migrating down'
  end

end