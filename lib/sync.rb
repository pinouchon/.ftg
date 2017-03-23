class Sync

  def initialize(jira_client, toggl_client)
    @jira_client = jira_client
    @toggl_client = toggl_client
  end

  # create_table :tasks do |t|
  #   t.string :name
  #   t.string :category
  #   t.integer :duration

  #
  #   t.integer :jira_logged_duration
  #   t.integer :jira_timelog_id
  #   t.datetime :jira_synced_at
  #
  #   t.date :day
  #   t.datetime :edited_at
  #   t.datetime :deleted_at
  #   t.timestamps
  # end
  def run(day)
    scope = Task.where(day: day)

    # tasks that need deletion
    scope.deleted.where('toggl_activity_id IS NOT NULL').each do |task|
      delete_from_toggl(task)
    end
    # scope.deleted.where('jira_timelog_id IS NOT NULL').each do |task|
    #   delete_from_jira(task)
    # end

    # tasks that need synchronisation
    scope.not_deleted.where('duration IS NOT toggl_logged_duration').each do |task|
      sync_toggl(task)
    end
    # scope.not_deleted.where('duration IS NOT jira_logged_duration').each do |task|
    #   sync_jira(task)
    # end
  end

  def delete_from_toggl(task)
    activity_id = task.toggl_activity_id
    print "Deleting toggl activity #{activity_id} for #{task.name.cyan}... "
    result = @toggl_client.delete_activity(activity_id)
    if result && result.is_a?(Array) && result[0] == activity_id
      puts 'ok'.green
      task.toggl_logged_duration = nil
      task.toggl_activity_id = nil
      task.toggl_synced_at = Time.now
      task.save
    else
      puts "Error: #{result}"
    end
  end

  def delete_from_jira(task)
    worklog_id = task.jira_timelog_id
    print "Deleting jira worklog #{worklog_id} for #{task.name.cyan}... "
    result = @jira_client.delete_worklog(task)
    if result == 'ok'
      puts 'ok'.green
      task.jira_logged_duration = nil
      task.jira_timelog_id = nil
      task.jira_synced_at = Time.now
      task.save
    else
      puts "Error: #{result}"
    end
  end

  def sync_toggl(task)
    return if task.toggl_logged_duration == task.duration

    if task.toggl_activity_id.present?
      delete_from_toggl(task)
    end
    print "Creating toggl activity for #{task.name.cyan}... "
    result = @toggl_client.create_activity("#{task.name} [FTG]", task.duration, task.day, task.category)

    if result['data'] && result['data']['id']
      puts "ok".green
      task.toggl_logged_duration = result['data']['duration']
      task.toggl_activity_id = result['data']['id']
      task.toggl_synced_at = Time.now
      task.save
    else
      puts "ERROR!\n#{result}"
    end
  end

  def sync_jira(task)
    return if task.jira_logged_duration == task.duration
    return unless task.jira_id

    if task.jira_timelog_id.present?
      delete_from_jira(task)
    end

    print "Creating jira worklog for #{task.name.cyan}... "
    result = @jira_client.create_worklog(task)

    if result && result['id']
      puts "ok".green
      task.jira_logged_duration = result['timeSpentSeconds']
      task.jira_timelog_id = result['id']
      task.jira_synced_at = Time.now
      task.save
    else
      puts "ERROR!\n#{result}"
    end
  end

end
