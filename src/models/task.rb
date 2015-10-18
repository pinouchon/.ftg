class Task < ActiveRecord::Base
  def duration_formatted
    Utils.format_time(duration)
  end
end