require_relative '../colors'
require_relative '../utils'
require_relative './ftg_options'
require_relative './ftg_logger'
require 'json'
require 'date'

class Ftg
  include FtgOptions

  def initialize
    @commands = {
      help: { fn: -> { help }, aliases: [] },
      recap: { fn: -> {
        gtfo(day_option, get_option(['--restore']), get_option(['--reset'])) # option union
      }, aliases: [:gtfo, :leave, :wrap_up] },
      status: { fn: -> { status }, aliases: [:stack] },
      console: { fn: -> { console }, aliases: [:shell] },
      current: { fn: -> { current }, aliases: [] },
      git_stats: { fn: -> { git_stats }, aliases: [] },
      start: { fn: -> { start(ARGV[1]) }, aliases: [:begin] },
      stop: { fn: -> { stop(get_option(['--all'])) }, aliases: [:end] },
      pop: { fn: -> { stop(nil); resume }, aliases: [] },
      pause: { fn: -> { pause }, aliases: [] },
      resume: { fn: -> { resume }, aliases: [] },
      edit: { fn: -> {
        edit(day_option, get_option(['--restore']), get_option(['--reset'])) # option union
      }, aliases: [] },
      list: { fn: -> { list(get_option(['--day', '-d'])) }, aliases: [:ls, :history, :recent] },
      sync: { fn: -> { sync(day_option) }, aliases: [] },
      config: { fn: -> { config }, aliases: [] },
      touch: { fn: -> { touch(ARGV[1]) }, aliases: [] },
      rename: { fn: -> { rename(ARGV[1], ARGV[2]) }, aliases: [] },
      delete: { fn: -> { delete(ARGV[1]) }, aliases: [:remove] },
      email: { fn: -> { email(day_option) }, aliases: [:mail] },
      categories: { fn: -> { categories }, aliases: [] },
      auto: { fn: -> { start('auto') }, aliases: [] },
      migrate: { fn: -> { migrate(get_option(['--down'])) }, aliases: [] },
      coffee: { fn: -> { coffee(get_option(['--big'])) } }
    }

    @ftg_dir = "#{ENV['HOME']}/.ftg"
    private_config = JSON.parse(File.open("#{@ftg_dir}/config/private.json", 'r').read)
    public_config = JSON.parse(File.open("#{@ftg_dir}/config/public.json", 'r').read)
    @config = public_config.deep_merge(private_config)
    @ftg_logger = FtgLogger.new(@ftg_dir)
  end

  def require_models
    require 'active_record'
    require_relative '../models/task'
    require_relative '../models/category_cache'
    require_relative '../migrations/create_tasks'
    require_relative '../migrations/create_category_caches'
    require_relative '../task_formatter'

    ActiveRecord::Base.establish_connection(
      adapter: 'sqlite3',
      database: "#{@ftg_dir}/db/ftg.sqlite3"
    )
    fail('Cannot open task connection') unless Task.connection
    fail('Cannot open category_cache connection') unless CategoryCache.connection
  end

  def require_clients
    require_relative '../api_clients/api_client'
    require_relative '../api_clients/toggl_client'
    require_relative '../api_clients/jira_client'

    [
      JiraClient.new(@config['ftg']['plugins']['jira']),
      TogglClient.new(@config['ftg']['plugins']['toggl'])
    ]
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
  recap                              Executes: edit, sync, mail
  edit <task> [-d <day>, --reset]    Manually edit times
  sync [-d <day>]                    Sync times with jira and toggl
  mail                               Send an email
  git_stats                          Show git branch times
  status                             Show current task and status
  auto                               Auto mode (by default). Track based on git branch
  touch <task>                       Start and end a task right away
  remove <task>                      Delete a task
  rename <from> <to>                 Rename a task
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
    if task && task[/_/]
      puts 'Warning:'.red + ' Use - instead of _ in task names (correct with ' +
             "ftg rename #{task} #{task.gsub('_', '-')}".yellow + ')'
    end
    if task == 'current_branch'
      task = `git rev-parse --abbrev-ref HEAD`.strip
    end
    if task.nil? || task == ''
      STDERR.puts 'Enter category/task. Example: ' + 'ftg start meeting/sprint'.yellow
      STDERR.puts 'Recent tasks:'
      STDERR.puts (get_list(nil)[0, 10] + ['-' * 30] + config_tasks).map { |e| "  #{e}" }.join("\n")
      fail
    end
    if @ftg_logger.on_pause?
      @ftg_logger.add_log('ftg_stop', 'pause')
    end
    if @ftg_logger.get_unclosed_logs.find { |l| l[:task_name] == task }
      status
      fail("\nTask #{task} already started")
    end
    if !Utils.extract_jt(task) && !task[/\//] && task != 'auto' && task != 'pause'
      STDERR.puts "Enter #{'category'.yellow}/task. Example: " + 'ftg start meeting/sprint'.yellow
      STDERR.puts 'Available categories:'
      STDERR.puts get_categories.map { |e| "  #{e}" }.join("\n")
      fail
    end
    if !Utils.extract_jt(task) && task[/\//] && !get_categories.include?(c = task.split('/')[0])
      STDERR.puts "Invalid category #{(c||'').yellow}"
      STDERR.puts 'Available categories:'
      STDERR.puts get_categories.map { |e| "  #{e}" }.join("\n")
      fail
    end
    @ftg_logger.add_log('ftg_start', task)
    status
    @ftg_logger.update_current
  end

  def stop(all)
    @ftg_logger.get_unclosed_logs.each do |log|
      @ftg_logger.add_log('ftg_stop', log[:task_name])
      unless all
        @ftg_logger.add_log('ftg_start', 'auto') unless log[:task_name] == 'auto'
        break
      end
    end

    status
    @ftg_logger.update_current
  end

  def pause
    if @ftg_logger.on_pause?
      status
      fail("\nAlready on pause")
    end
    @ftg_logger.add_log('ftg_start', 'pause')
    status
    @ftg_logger.update_current
  end

  def resume
    unclosed_logs = @ftg_logger.get_unclosed_logs
    if unclosed_logs[0] && unclosed_logs[0][:task_name] == 'auto' &&
      unclosed_logs.find { |e| !['auto', 'pause'].include?(e[:task_name]) }
      @ftg_logger.add_log('ftg_stop', 'auto')
    elsif unclosed_logs[0] && unclosed_logs[0][:task_name] == 'pause'
      @ftg_logger.add_log('ftg_stop', 'pause')
    else
      puts 'Nothing to resume. You can only resume while on "pause" or "auto"'
      puts
    end

    status
    @ftg_logger.update_current
  end

  def touch(task)
    @ftg_logger.add_log('ftg_start', task)
    @ftg_logger.add_log('ftg_stop', task)
    status
  end

  def rename(from, to)
    if %w(ftg_start ftg_end).include?(from) || %w(ftg_start ftg_end).include?(to) ||
      from.numeric? || to.numeric?
      fail('Param must be a task name')
    end
    count = @ftg_logger.search_and_replace(from, to)
    if count == 0
      puts "\"#{from}\" not found in logs"
    else
      puts "#{count} occurrences replaced (#{from} -> #{to})"
    end

    @ftg_logger.update_current
    status
  end

  def delete(task)
    if task == '--all'
      @ftg_logger.remove_all_logs
    end
    @ftg_logger.remove_logs(task)
    status
    @ftg_logger.update_current
  end

  def gtfo(day, restore, reset)
    edit(day, restore, reset)
    email(day)
    sync(day)
  end

  def working_on_text(task_name)
    return 'On pause' if task_name == 'pause'
    return 'auto' if task_name == 'auto'
    "Now working on: [#{task_name.cyan}]"
  end

  def status
    current_logs = @ftg_logger.get_unclosed_logs
    if current_logs.empty?
      puts 'No current task'
    else
      task_name = current_logs[0][:task_name]
      puts working_on_text(task_name)
      unless current_logs[1..-1].empty?
        puts "next tasks: #{current_logs[1..-1].map { |l| l[:task_name].light_blue }.join(', ')}"
      end
    end
  end

  def current
    puts `cat #{@ftg_dir}/current.txt`
  end

  def ftg_category(jira_category)
    return 'maintenance' if jira_category == 'Maintenance'
    return 'sprint' if jira_category.present?
    nil
  end

  def assign_jt_categories(tasks)
    jira_client, _ = require_clients
    tasks.each do |task|
      next if !task.jira_id || task.category
      category_cache = CategoryCache.where(name: task.jira_id).first_or_create
      if category_cache.category.nil?
        print "Getting category of #{task.name}... "
        category = ftg_category(jira_client.jira_category(task.jira_id))
        puts category.green
        category_cache.category = category
        category_cache.save
      end
      task.category = category_cache.category
      task.save
    end
  end

  def edit(day, restore, reset)
    print 'Initializing the awesome...'

    require_relative '../interactive'
    require_relative './ftg_stats'
    require_models

    ftg_stats = FtgStats.new(day == Time.now.strftime('%F'), day, config_tasks)
    tasks = []
    Hash[ftg_stats.stats][day].each do |branch, by_branch|
      next if branch == 'unknown'
      by_idle = Hash[by_branch]
      task_name = branch[/\//] ? branch.split('/')[1] : branch
      task = Task.where(day: day).where(name: task_name).first_or_create
      task.category = branch.split('/')[0] if branch[/\//]
      task.duration = (task.edited_at && !reset) ? task.duration : by_idle[false].to_i
      task.save
      tasks << task if restore || reset || !task.deleted_at
    end

    assign_jt_categories(tasks)
    deleted_tasks = Interactive.new.interactive_edit(tasks, day)
    tasks.each do |task|
      task.deleted_at = nil if restore || reset
      task.save if restore || task.changed.include?('edited_at')
    end
    deleted_tasks.each do |task|
      task.save if task.changed.include?('deleted_at')
    end
  end

  def sync(day)
    require_relative '../sync'
    require_models

    Sync.new(*require_clients).run(day)
  end

  def git_stats
    require_relative './ftg_stats'
    FtgStats.new(false).run
  end

  def config_tasks
    @config['ftg']['default_tasks'][Time.now.strftime('%A').downcase] +
      @config['ftg']['default_tasks']['everyday']
  end

  def get_list(days)
    days ||= 14
    begin_time = Time.now.to_i - (days.to_i * 24 * 3600)

    # Date.parse(day).to_time.to_i
    git_branches_raw = `git for-each-ref --sort=-committerdate --format='%(refname:short) | %(committerdate:iso)' refs/heads/` rescue []

    git_branches = []
    git_branches_raw.split("\n").map do |b|
      parts = b.split(' | ')
      next if parts.count != 2
      timestamp = DateTime.parse(parts[1]).to_time.to_i
      if timestamp > begin_time
        git_branches << [timestamp, parts[0]]
      end
    end

    commands_log_path = "#{@ftg_dir}/log/commands.log"
    history_branches = []
    `tail -n #{days * 500} #{commands_log_path}`.split("\n").each do |command|
      parts = command.split("\t")
      time = parts[5].to_i
      branch = parts[4]
      if time > begin_time && branch != 'no_branch'
        history_branches << [time, branch]
      end
    end
    history_branches = history_branches.group_by { |e| e[1] }.map { |k, v| [v.last[0], k] }

    ftg_log_path = "#{@ftg_dir}/log/ftg.log"
    ftg_tasks = []
    `tail -n #{days * 100} #{ftg_log_path}`.split("\n").each do |log|
      parts = log.split("\t")
      task = parts[1]
      time = parts[2].to_i
      if time > begin_time
        ftg_tasks << [time, task]
      end
    end
    ftg_tasks = ftg_tasks.group_by { |e| e[1] }.map { |k, v| [v.last[0], k] }

    all_tasks = git_branches + history_branches + ftg_tasks
    all_tasks = all_tasks.sort_by { |e| -e[0] }.group_by { |e| e[1] }.map { |task, times| task }
    all_tasks.select { |e| !%w(pause auto master staging develop).include?(e) }
  end

  def list(days)
    puts (get_list(days) + ['-' * 30] + config_tasks).join("\n")
  end

  def get_categories
    @config['ftg']['projects']
  end

  def categories
    puts get_categories.join("\n")
  end

  def migrate(down)
    require_models
    if down
      CreateCategoryCaches.new.down
      CreateTasks.new.down
    else
      CreateTasks.new.up
      CreateCategoryCaches.new.up
    end
  end

  def render_email(day, tasks)
    max_len = TaskFormatter.max_length(tasks)
    content = "Salut,\n\n<Expliquer ici pourquoi le sprint ne sera pas fini à temps>\n\n#{day}\n"
    content += tasks.map do |task|
      TaskFormatter.new(20).format(task, max_len).line_for_email
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
    require_relative '../interactive'
    require_relative './ftg_stats'
    require_models
    binding.pry
  end

  def coffee(big = false)
    require_relative '../coffee'
    puts(big ? Coffee.coffee2 : Coffee.coffee1)
    puts "\nHave a nice coffee !"
    puts '=========================================='
    pause
  end
end

Ftg.new.run