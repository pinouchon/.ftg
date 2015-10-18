class ::Hash
  def deep_merge(second)
    merger = proc { |key, v1, v2| Hash === v1 && Hash === v2 ? v1.merge(v2, &merger) : v2 }
    self.merge(second, &merger)
  end
end

class Utils
  # def self.format_time(seconds)
  #   seconds ||= 0
  #   Time.at(seconds.round).utc.strftime('%H:%M:%S')#%Y %M %D
  # end

  def self.format_time(secs)
    # secs ||= 0
    # Time.at(secs.round).utc.strftime('%Hh %Mm')
    secs ||= 0
    '%02sh %02dm' % [secs / 3600, (secs / 60) % 60]
  end
end