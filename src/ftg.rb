require_relative './colors'
require_relative './utils'
require_relative './ftg_options'
require_relative './ftg_logger'
require 'json'
require 'date'

class Ftg
  include FtgOptions

  def initialize

    @commands = {
      help: { fn: -> { help }, aliases: [] },
      gtfo: { fn: -> {
        gtfo(day_option, get_option(['--restore']), get_option(['--reset'])) # option union
      }, aliases: [:recap, :leave, :wrap_up] },
      status: { fn: -> { status }, aliases: [:current, :stack] },
      git_stats: { fn: -> { git_stats }, aliases: [] },
      start: { fn: -> { start(ARGV[1]) }, aliases: [] },
      stop: { fn: -> { stop(get_option(['--all'])) }, aliases: [:end, :pop] },
      pause: { fn: -> { pause }, aliases: [] },
      resume: { fn: -> { resume }, aliases: [] },
      edit: { fn: -> {
        edit(day_option, get_option(['--restore']), get_option(['--reset'])) # option union
      }, aliases: [] },
      list: { fn: -> { list }, aliases: [:ls, :history, :recent] },
      sync: { fn: -> { sync }, aliases: [] },
      config: { fn: -> { config }, aliases: [] },
      touch: { fn: -> { touch(ARGV[1]) }, aliases: [] },
      delete: { fn: -> { delete(ARGV[1]) }, aliases: [:remove] },
      email: { fn: -> { email(day_option) }, aliases: [:mail] },
      migrate: { fn: -> { migrate }, aliases: [] },
      console: { fn: -> { console }, aliases: [:shell] },
      coffee: { fn: -> { coffee(get_option(['--big'])) } }
    }

    @ftg_dir = "#{ENV['HOME']}/.ftg"
    private_config = JSON.parse(File.open("#{@ftg_dir}/config/private.json", 'r').read)
    public_config = JSON.parse(File.open("#{@ftg_dir}/config/public.json", 'r').read)
    @config = public_config.deep_merge(private_config)
    @ftg_logger = FtgLogger.new("#{@ftg_dir}/log/ftg.log")
  end


  def require_models
    require 'active_record'
    require_relative './models/task'
    require_relative './migrations/create_tasks'
    require_relative './task_formatter'

    ActiveRecord::Base.establish_connection(
      adapter: 'sqlite3',
      database: 'db/ftg.sqlite3'
    )
    fail('Cannot open task connection') unless Task.connection
  end

  def run
    help(1) if ARGV[0].nil?
    cmd = get_command(ARGV[0])
    fail("Unknown command #{ARGV[0]}") if cmd.nil?
    cmd[1][:fn].call
  end

#####################################################################################
####################################### COMMANDS ####################################
#####################################################################################

  def help(exit_code = 0)
    help = <<-HELP
Usage: ftg <command> [arguments...]
By default, the day param is the current day.

Command list:
  start, stop, pause, resume <task>  Manage tasks
  gtfo                               Executes: edit, sync, mail
  edit <task> [-d <day>, --reset]    Manually edit times
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

  def config
    require 'ap'
    puts 'Settings are in the ./config folder:'
    puts '  public.json     default settings. Do not edit manually. Added to git'
    puts '  private.json    personal settings. This will overwrite public.json. Ignored in git'

    puts "\nCurrent config:\n"
    ap @config
  end

  def start(task)
    if task == 'auto' || task == 'current_branch'
      task = `git rev-parse --abbrev-ref HEAD`.strip
    end
    if task.nil? || task == ''
      fail('Enter a task. Eg: ftg start jt-1234')
    end
    if @ftg_logger.on_pause?
      status
      fail("\nCannot start a task while on pause. Use \"ftg resume\" first")
    end
    if @ftg_logger.get_unclosed_logs.find { |l| l[:task_name] == task }
      status
      fail("\nTask #{task} already started")
    end
    @ftg_logger.add_log('ftg_start', task)
    status
  end

  def stop(all)
    @ftg_logger.get_unclosed_logs.each do |log|
      @ftg_logger.add_log('ftg_stop', log[:task_name])
      break unless all
    end
    status
  end

  def pause
    if @ftg_logger.on_pause?
      status
      fail("\nAlready on pause")
    end
    @ftg_logger.add_log('ftg_start', 'pause')
    status
  end

  def resume
    @ftg_logger.add_log('ftg_stop', 'pause')
    status
  end

  def touch(task)
    @ftg_logger.add_log('ftg_start', task)
    @ftg_logger.add_log('ftg_stop', task)
    status
  end

  def delete(task)
    if task == '--all'
      @ftg_logger.remove_all_logs
    end
    @ftg_logger.remove_logs(task)
    status
  end

  def gtfo(day, restore, reset)
    edit(day, restore, reset)
    email(day)
    puts "sync soon..."
  end

  def status
    current_logs = @ftg_logger.get_unclosed_logs
    if current_logs.empty?
      puts 'No current task'
    else
      task_name = current_logs[0][:task_name]
      puts(task_name == 'pause' ? 'On pause' : "Now working on: [#{task_name.cyan}]")
      unless current_logs[1..-1].empty?
        puts "next tasks: #{current_logs[1..-1].map { |l| l[:task_name].light_blue }.join(', ')}"
      end
    end
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

  def git_stats
    require_relative './ftg_stats'
    FtgStats.new(false).run
  end

  def list

  end

  def migrate
    require_models
    CreateTasks.new.up
  end

  def render_email(day, tasks)
    max_len = TaskFormatter.max_length(tasks)
    content = "Salut,\n\n<Expliquer ici pourquoi le sprint ne sera pas fini à temps>\n\n#{day}\n"
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
    week_day_en = Time.now.strftime('%A').downcase
    greeting = @config['ftg']['greetings'][week_day_en] || nil
    subject = "Recap #{week_day_fr} #{day}"

    body = [render_email(day, Task.where(day: day).where(deleted_at: nil)), greeting].compact.join("\n\n")
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
    puts '=========================================='
    pause
  end
end


Ftg.new.run
