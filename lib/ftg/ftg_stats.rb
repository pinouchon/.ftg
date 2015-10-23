class FtgStats
  IDLE_THRESHOLD = 5 * 60

  attr_accessor :stats

  def initialize(only_last_day = false)
    load_data(only_last_day)
    crunch
    group
    # sync_toggl
  end

  def run

    display
    # sync_toggl
  end

  def search_idle_key(timestamp)
    (0..10).each do |k|
      key = timestamp + k
      return key if @idle_parts[key]
    end
    # puts("not found #{Utils.format_time(timestamp)}")
    nil
  end

  def load_data(only_last_day)
    home = `echo $HOME`.strip
    ftg_dir = "#{home}/.ftg"
    commands_log_path = "#{ftg_dir}/log/commands.log"
    idle_log_path = "#{ftg_dir}/log/idle.log"
    records_to_load = only_last_day ? 24 * 360 : 0
    @commands = {}
    @idle_parts = {}

    # sample row:
    # pinouchon       fg      no_alias        /Users/pinouchon/.ftg   no_branch       1438867098
    (only_last_day ?
      `tail -n #{records_to_load} #{commands_log_path}`.split("\n") :
      File.foreach(commands_log_path)).each do |line|
      parts = line.split("\t")
      next if !parts[5] || parts[5].empty?
      @commands[parts[5].strip.to_i] = { :user => parts[0],
                                         :command => parts[1],
                                         :alias => parts[2], :dir => parts[3], :branch => parts[4] }
    end

    (only_last_day ?
      `tail -n #{records_to_load} #{idle_log_path}`.split("\n") :
      File.foreach(idle_log_path)).each do |line|
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
  end

  def group
    @stats = @idle_parts.group_by { |ts, _| Time.at(ts).strftime('%F') }.map do |day, parts_by_day|
      [
        day,
        parts_by_day.group_by { |_, v| v[:branch] }.map do |branch, parts_by_branch|
          [
            branch,
            parts_by_branch.group_by { |_, v| v[:idle] }.map { |k, v| [k, v.count*10] }
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
        idle_str = by_idle[true] ? "(and #{Utils.format_time(by_idle[true])} idle)" : ''
        puts "  #{branch}: #{Utils.format_time(by_idle[false]) || '00:00:00'} #{idle_str}"
      end
    end
  end

  # Full sync
  def sync_toggl
    raise 'deprecated'
    require_relative 'ftg_sync'
    require 'pry'
    sync = FtgSync.new
    i = 0

    Hash[@stats].each do |day, by_day|
      puts "#{day}:"
      Hash[by_day].each do |branch, by_branch|
        by_idle = Hash[by_branch]
        idle_str = by_idle[true] ? "(and #{by_idle[true]} idle)" : ''
        puts "  #{branch}: #{by_idle[false] || '00:00:00'} #{idle_str}"

        if branch =~ /jt-/ && by_idle[false]
          ps = day.split('-')
          time = Time.new(ps[0], ps[1], ps[2], 12,0,0)
          begining_of_day = Time.new(ps[0], ps[1], ps[2], 0,0,0)
          end_of_day = begining_of_day + (24*3600)

          jt = branch[/(jt-[0-9]+)/]
          # duration_parts = by_idle[false].split(':')
          duration = by_idle[false].to_i
          # duration = duration_parts[0].to_i * 3600 + duration_parts[1].to_i * 60 + duration_parts[2].to_i
          type = sync.maintenance?(jt) ? :maintenance : :sprint
          sync.create_activity("#{branch} [via FTG]", duration, time, type)
          i += 1

          puts "logging #{branch}: #{by_idle[false]}"
        end
      end
    end
    puts "total: #{i}"
  end

end

# FtgStats.new