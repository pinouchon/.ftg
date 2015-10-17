require 'pry'
require_relative './colors'
require_relative './utils'

class Ftg
  def initialize
    @commands = {
      help: { fn: -> { help }, aliases: [] },
      status: { fn: -> { in_progress }, aliases: [] },
      stats: { fn: -> { stats }, aliases: [] },
      start: { fn: -> { in_progress }, aliases: [] },
      stop: { fn: -> { in_progress }, aliases: [] },
      pause: { fn: -> { in_progress }, aliases: [] },
      resume: { fn: -> { in_progress }, aliases: [] },
      current: { fn: -> { in_progress }, aliases: [] },
      pop: { fn: -> { in_progress }, aliases: [] },
      edit: { fn: -> { edit(get_option(['-d', '--day'])) }, aliases: [] },
      list: { fn: -> { in_progress }, aliases: [] },
      sync: { fn: -> { sync }, aliases: [] },
      config: { fn: -> { in_progress }, aliases: [] },
      touch: { fn: -> { in_progress }, aliases: [] },
      delete: { fn: -> { in_progress }, aliases: [:remove] },
      recap: { fn: -> { in_progress }, aliases: [:mailto] },
      migrate: { fn: -> { migrate }, aliases: [:mailto] },
      console: { fn: -> { console }, aliases: [:shell] },
    }
  end

  def get_option(names)
    ARGV.each_with_index do |opt_name, i|
      return ARGV[i + 1] if names.include?(opt_name)
    end
    nil
  end

  def require_models
    require 'active_record'
    require_relative './models/task'
    require_relative './migrations/create_tasks'

    ActiveRecord::Base.establish_connection(
      :adapter => 'sqlite3',
      :database => 'db/ftg.sqlite3'
    )
    fail('Cannot open task connection') unless Task.connection
    # ActiveRecord::Schema.define do
    #   create_table :tasks do |t|
    #     t.column :id
    #   end
    # end
  end

  def get_command(name)
    @commands.keys.find { |opt| opt.to_s.start_with?(name) }
  end

  def fail(message = nil)
    STDERR.puts message if message
    exit(1)
  end

  def run
    help(1) if ARGV[0].nil?
    cmd = get_command(ARGV[0])
    fail("Unknown command #{ARGV[0]}") if cmd.nil?
    @commands[cmd][:fn].call
  end

  def help(exit_code = 0)
    help = <<-HELP
Usage: ftg <command> [arguments...]
By default, the day param is the current day.

Command list:
  start, stop, pause, resume <task>  Manage tasks
  recap                              Executes: edit, sync, mail
  edit <task>                        Manually edit times
  sync [-d <day>]                    Sync times with jira and toggl
  mail                               Send an email
  stats [-d <day>]                   Show time stats
  current                            Show current task
  pop                                Stop current task and resume previous one
  touch <task>                       Start and end a task right away
  remove <task>                      Delete a task
  list                               List of tasks/meetings of the day
  config                             Show config files
  console                            Open a console
HELP
    puts help
    exit(exit_code)
  end

  def is_integer?(str)
    str.to_i.to_s == str
  end

  def edit(time)
    require_relative './interactive'
    require_relative './ftg_stats'
    require_models

    time ||= '0'
    ftg_stats = FtgStats.new(time == '0')
    day = is_integer?(time) ?
      Time.at(Time.now.to_i - time.to_i * 86400).strftime('%F') :
      Time.parse(time).strftime('%F')

    # by_day[day].each do ||
    tasks = []
    Hash[ftg_stats.stats][day].each do |branch, by_branch|
      next if branch == 'unknown'
      by_idle = Hash[by_branch]
      task = Task.where(day: day).where(name: branch).first_or_create
      task.duration = by_idle[false].to_i
      task.save
      tasks << task
    end

    Interactive.new.interactive_edit(tasks)
    tasks.each do |task|
      task.edited_at = Time.now
      task.save
    end
  end

  def sync
    require_relative './ftg_sync'
    abort('todo')
  end

  def stats
    require_relative './ftg_stats'
    FtgStats.new(false).run
  end

  def migrate
    require_models
    CreateTasks.new.up
  end

  def in_progress
    abort('in progress...')
  end

  def console
    require 'pry'
    require_relative './interactive'
    require_relative './ftg_stats'
    require_models
    binding.pry
  end
end


Ftg.new.run
