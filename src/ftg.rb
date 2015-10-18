require 'pry'
require_relative './colors'
require_relative './utils'
require 'json'
require 'date'

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
      edit: { fn: -> {
        edit(day_option, get_option(['--restore']), get_option(['--reset']))
      }, aliases: [] },
      list: { fn: -> { in_progress }, aliases: [] },
      sync: { fn: -> { sync }, aliases: [] },
      config: { fn: -> { in_progress }, aliases: [] },
      touch: { fn: -> { in_progress }, aliases: [] },
      delete: { fn: -> { in_progress }, aliases: [:remove] },
      email: { fn: -> { email(day_option) }, aliases: [] },
      recap: { fn: -> { in_progress }, aliases: [] },
      migrate: { fn: -> { migrate }, aliases: [] },
      console: { fn: -> { console }, aliases: [] },
      coffee: { fn: -> { coffee(get_option(['--big'])) } }
    }

    private_config = JSON.parse(File.open("#{ENV['HOME']}/.ftg/config/private.json", 'r').read)
    public_config = JSON.parse(File.open("#{ENV['HOME']}/.ftg/config/public.json", 'r').read)
    @config = public_config.deep_merge(private_config)
  end

  def get_option(names)
    ARGV.each_with_index do |opt_name, i|
      return (ARGV[i + 1] || 1) if names.include?(opt_name)
    end
    nil
  end

  def day_option
    day_option = get_option(['-d', '--day'])
    day_option ||= '0'

    is_integer?(day_option) ?
      Time.at(Time.now.to_i - day_option.to_i * 86400).strftime('%F') :
      Date.parse(day_option).strftime('%F')
  end

  def require_models
    require 'active_record'
    require_relative './models/task'
    require_relative './migrations/create_tasks'
    require_relative './task_formatter'

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
  edit <task> [-d <day>, --restore]  Manually edit times
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

  def edit(day, restore, reset)
    require_relative './interactive'
    require_relative './ftg_stats'
    require_models

    ftg_stats = FtgStats.new(day == Time.now.strftime('%F'))
    tasks = []
    Hash[ftg_stats.stats][day].each do |branch, by_branch|
      next if branch == 'unknown'
      by_idle = Hash[by_branch]
      scope = Task.where(day: day).where(name: branch)
      scope.delete_all if reset
      task = scope.first_or_create
      task.duration = task.edited_at ? task.duration : by_idle[false].to_i
      task.save
      tasks << task if restore || !task.deleted_at
    end

    deleted_tasks = Interactive.new.interactive_edit(tasks)
    tasks.each do |task|
      task.deleted_at = nil if restore
      task.save if restore || task.changed.include?('edited_at')
    end
    deleted_tasks.each do |task|
      task.save if task.changed.include?('deleted_at')
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

  def render_email(day, tasks)
    max_len = TaskFormatter.max_length(tasks)
    content = "Salut,\n\nblabla\n\n#{day}\n"
    content += tasks.map do |task|
      TaskFormatter.new.format(task, max_len).line_for_email
    end.join("\n")
    content
  end

  def email(day)
    require_models
    email = @config['ftg']['recap_mailto'].join(', ')
    week_days_fr = ['lundi', 'mardi', 'mercredi', 'jeudi', 'vendredi', 'samedi', 'dimanche']
    week_day_fr = week_days_fr[Date.parse(day).strftime('%u').to_i - 1]
    subject = "Recap #{week_day_fr} #{day}"
    body = render_email(day, Task.where(day: day).where(deleted_at: nil))
    system('open', "mailto: #{email}?subject=#{subject}&body=#{body}")
  end

  def console
    require 'pry'
    require_relative './interactive'
    require_relative './ftg_stats'
    require_models
    binding.pry
  end

  def coffee(big = false)
    require_relative './coffee'
    puts(big ? Coffee.coffee2 : Coffee.coffee1)
    puts "\nHave a nice coffee !"
    # call pause
  end
end


Ftg.new.run
