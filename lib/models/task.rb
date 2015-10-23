class Task < ActiveRecord::Base
  def duration_formatted
    Utils.format_time(duration)
  end

  def jira_id
    match = name[/^jt-[0-9]+/]
    match ? match.upcase : nil
  end

  def self.not_deleted
    where(deleted_at: nil)
  end

  def self.deleted
    where('deleted_at IS NOT NULL')
  end
end