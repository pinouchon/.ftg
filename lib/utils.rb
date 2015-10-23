class ::Hash
  def deep_merge(second)
    merger = proc { |key, v1, v2| Hash === v1 && Hash === v2 ? v1.merge(v2, &merger) : v2 }
    self.merge(second, &merger)
  end
end

class Utils

  def self.format_time(secs)
    # Time.at(secs.round).utc.strftime('%Hh %Mm')
    secs ||= 0
    '%02sh %02dm' % [secs / 3600, (secs / 60) % 60]
  end

  def self.is_integer?(str)
    str.to_i.to_s == str
  end

end