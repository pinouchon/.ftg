class CreateTasks < ActiveRecord::Migration
  def up
    create_table :tasks do |t|
      t.string :name
      t.string :category
      t.integer :duration

      t.integer :toggl_logged_duration
      t.integer :toggl_activity_id
      t.datetime :toggl_synced_at

      t.integer :jira_logged_duration
      t.integer :jira_timelog_id
      t.datetime :jira_synced_at

      t.date :day
      t.datetime :edited_at
      t.datetime :deleted_at
      t.timestamps
    end
  end

  def down
    drop_table :tasks
  end

end