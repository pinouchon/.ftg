class ::Hash
  def deep_merge(second)
    merger = proc { |key, v1, v2| Hash === v1 && Hash === v2 ? v1.merge(v2, &merger) : v2 }
    self.merge(second, &merger)
  end
end

class String
  def numeric?
    Float(self) != nil rescue false
  end
end

class Array
  def odd_values
    self.values_at(* self.each_index.select {|i| i.odd?})
  end
  def even_values
    self.values_at(* self.each_index.select {|i| i.even?})
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

  def self.extract_jt(name)
    match = name[/^(jt|data)-[0-9]+/i]
    match ? match.upcase : nil
  end

end