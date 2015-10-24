class Task < ActiveRecord::Base
  def duration_formatted
    Utils.format_time(duration)
  end

  def jira_id
    Utils.extract_jt(name)
  end

  def name_with_category
    "#{category}/#{name}"
  end

  def self.not_deleted
    where(deleted_at: nil)
  end

  def self.deleted
    where('deleted_at IS NOT NULL')
  end
end