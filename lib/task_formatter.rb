class TaskFormatter

  attr_accessor :bar_size, :max_width

  def initialize(bar_size = 40, max_width = 94)
    @bar_size = bar_size
    @max_width = max_width
    @task = nil
  end

  def format(task, task_len)
    @task = task
    @task_len = task_len
    self
  end

  def self.max_length(tasks)
    [tasks.map { |e| e.name_with_category.length }.max || 0, 60].min
  end

  def time_bar(full_char = '=', empty_char = ' ', ellipsis = '...')
    time_len = [@task.duration / 300, bar_size].min
    if time_len >= bar_size
      "[#{(full_char * (time_len - 2)) + ellipsis}"
    else
      "[#{full_char * time_len}#{empty_char * (bar_size - time_len)}]"
    end
  end

  def sync_status
    cond = @task.jira_logged_duration == @task.duration && @task.toggl_logged_duration == @task.duration
    # @task.jira_synced_at && @task.toggl_synced_at ? '✔' : '✘'
    cond ? '✔' : '✘'
  end

  def line_for_interactive
    task_formatted = @task.name_with_category[0, @task_len].ljust(@task_len, ' ')
    "  #{task_formatted} #{@task.duration_formatted}  #{time_bar}"
  end

  def line_for_email
    task_formatted = @task.name_with_category[0, @task_len]
    jt = @task.jira_id
    jira_link = jt ? "https://jobteaser.atlassian.net/browse/#{jt}" : ''
    "  #{time_bar('#', '  ', '..')} #{@task.duration_formatted}  #{task_formatted} #{jira_link}"
  end

end