class FtgStats
  IDLE_THRESHOLD = 5 * 60

  attr_accessor :stats

  def initialize(only_last_day = false, day = nil, extra_tasks = nil)
    @offset = 0
    @day = day
    @extra_tasks = extra_tasks

    load_data(only_last_day, day)
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

  def load_data(only_last_day, day)
    home = `echo $HOME`.strip
    ftg_dir = "#{home}/.ftg"
    commands_log_path = "#{ftg_dir}/log/commands.log"
    idle_log_path = "#{ftg_dir}/log/idle.log"
    ftg_commands_log_path = "#{ftg_dir}/log/ftg.log"
    records_to_load = only_last_day ? 24 * 360 : 0
    @commands = {}
    @idle_parts = {}
    @ftg_commands = []

    # sample row:
    # pinouchon       fg      no_alias        /Users/pinouchon/.ftg   no_branch       1438867098
    (only_last_day ?
      `tail -n #{records_to_load} #{commands_log_path}`.encode!('UTF-8', 'binary', invalid: :replace, undef: :replace, replace: '').split("\n") :
      File.foreach(commands_log_path)).each do |line|
      parts = line.encode('UTF-8', :invalid => :replace).split("\t")
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

    (only_last_day ?
      `tail -n #{records_to_load} #{ftg_commands_log_path}`.split("\n") :
      File.foreach(ftg_commands_log_path)).each do |line|
      parts = line.split("\t")
      # command arg timestamp
      next if !parts[2] || parts[2].empty?
      @ftg_commands << { ts: parts[2].strip.to_i, command: parts[0], args: parts[1] }
    end

    if day
      time = Time.parse(day)
      start = time.to_i
      ending = time.to_i + 24 * 3600
      @commands.keep_if { |k, _| start < k && k < ending }
      @idle_parts.keep_if { |k, _| start < k && k < ending }
      @ftg_commands.keep_if { |e| start < e[:ts] && e[:ts] < ending }
    end
  end

  def replay_ftg_logs
    command_stack = []
    previous = nil
    @ftg_commands.each do |ftg_command|
      if previous && command_stack[-1] && !%w(master staging develop auto).include?(command_stack[-1][:args])
        selected_parts = @idle_parts.select do |ts|
          previous[:ts] <= ts && ts <= ftg_command[:ts]
        end
        if selected_parts.count == 0
          @idle_parts[previous[:ts] + @offset] = { time_elapsed: '0',
                                         branch: command_stack[-1][:args],
                                         idle: false }
          @offset += 1
        end
        selected_parts.each do |_, idle_part|
          if command_stack[-1][:args] == 'pause'
            idle_part[:idle] = true
          else
            idle_part[:branch] = command_stack[-1][:args]
          end
        end
      end

      if ftg_command[:command] == 'ftg_start'
        command_stack << ftg_command
      end

      if ftg_command[:command] == 'ftg_stop'
        if command_stack.empty?
          puts 'Warning: Stack empty.'
        elsif command_stack[-1][:args] != ftg_command[:args]
          puts "Warning: #{ftg_command[:args]} not at the top of the stack"
        else
          command_stack.pop
        end
      end

      previous = ftg_command
    end

    time = Time.parse(@day) + 19 * 3600
    @extra_tasks.each_with_index do |task, i|
      @idle_parts[time.to_i + i] = { time_elapsed: '0',
                                     branch: task,
                                     idle: false }
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

    replay_ftg_logs if @day
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
  # def sync_toggl
  #   raise 'deprecated'
  #   require_relative 'ftg_sync'
  #   require 'pry'
  #   sync = FtgSync.new
  #   i = 0
  #
  #   Hash[@stats].each do |day, by_day|
  #     puts "#{day}:"
  #     Hash[by_day].each do |branch, by_branch|
  #       by_idle = Hash[by_branch]
  #       idle_str = by_idle[true] ? "(and #{by_idle[true]} idle)" : ''
  #       puts "  #{branch}: #{by_idle[false] || '00:00:00'} #{idle_str}"
  #
  #       if branch =~ /jt-/ && by_idle[false]
  #         ps = day.split('-')
  #         time = Time.new(ps[0], ps[1], ps[2], 12, 0, 0)
  #         begining_of_day = Time.new(ps[0], ps[1], ps[2], 0, 0, 0)
  #         end_of_day = begining_of_day + (24*3600)
  #
  #         jt = branch[/(jt-[0-9]+)/]
  #         # duration_parts = by_idle[false].split(':')
  #         duration = by_idle[false].to_i
  #         # duration = duration_parts[0].to_i * 3600 + duration_parts[1].to_i * 60 + duration_parts[2].to_i
  #         type = sync.maintenance?(jt) ? :maintenance : :sprint
  #         sync.create_activity("#{branch} [via FTG]", duration, time, type)
  #         i += 1
  #
  #         puts "logging #{branch}: #{by_idle[false]}"
  #       end
  #     end
  #   end
  #   puts "total: #{i}"
  # end

end
