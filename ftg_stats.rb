# F*** toggle

class FtgStats
  IDLE_THRESHOLD = 5 * 60

  def initialize
  end

  def run
    load_data
    crunch
    group
    display
  end

  def format_time(seconds)
    Time.at(seconds.round).utc.strftime('%H:%M:%S')#%Y %M %D
  end

  def search_idle_key(timestamp)
    (0..10).each do |k|
      key = timestamp + k
      return key if @idle_parts[key]
    end
    # puts("not found #{format_time(timestamp)}")
    nil
  end

  def load_data
    home = `echo $HOME`.strip
    ftg_dir = "#{home}/.ftg"
    @commands = {}
    @idle_parts = {}

    File.foreach("#{ftg_dir}/commands.log").each do |line|
      # pinouchon       fg      no_alias        /Users/pinouchon/.ftg   no_branch       1438867098
      parts = line.split("\t")
      next if !parts[5] || parts[5].empty?
      @commands[parts[5].strip.to_i] = { :user => parts[0],
                                         :command => parts[1],
                                         :alias => parts[2], :dir => parts[3], :branch => parts[4] }
    end

    File.foreach("#{ftg_dir}/idle.log").each do |line|
      parts = line.split("\t")
      next if !parts[1] || parts[1].empty?
      @idle_parts[parts[1].strip.to_i] = { :time_elapsed => parts[0] }
    end
  end

  def crunch
    # tagging branches in idle_parts
    @commands.each do |timestamp, command_info|
      if (key = search_idle_key(timestamp))
        @idle_parts[key][:branch] = command_info[:branch]
      end
    end

    # filling branches in idle_parts
    # tagging thresholds in idle_parts
    last_branch = 'unknown'
    @idle_parts.each do |timestamp, part|
      if part[:branch] && part[:branch] != '' && part[:branch] != 'no_branch'
        last_branch = part[:branch]
      end
      # puts "setting to #{last_branch} (#{Time.at(timestamp).strftime('%Y/%m/%d at %I:%M%p')})"
      @idle_parts[timestamp][:branch] = last_branch
      @idle_parts[timestamp][:idle] = part[:time_elapsed].to_i > IDLE_THRESHOLD
    end
    # require 'pry'
    # binding.pry
  end

  def group
    @stats = @idle_parts.group_by { |ts, _| Time.at(ts).strftime('%F') }.map do |day, parts_by_day|
      [
        day,
        parts_by_day.group_by { |_, v| v[:branch] }.map do |branch, parts_by_branch|
          [
            branch,
            parts_by_branch.group_by { |_, v| v[:idle] }.map { |k, v| [k, format_time(v.count*10)] }
          ]
        end
      ]
    end
  end

  def display
    Hash[@stats].each do |day, by_day|
      puts "#{day}:"
      Hash[by_day].each do |branch, by_branch|
        by_idle = Hash[by_branch]
        idle_str = by_idle[true] ? "(and #{by_idle[true]} idle)" : ''
        puts "  #{branch}: #{by_idle[false] || '00:00:00'} #{idle_str}"
      end
    end
  end

end

FtgStats.new.run