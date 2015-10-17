# require 'pry'
require_relative './interactive'
require_relative './colors'
require_relative './ftg_stats'
require_relative './ftg_sync'

class Ftg
  def initialize

    @options = {
      help: { fn: -> { help }, aliases: [] },
      status: { fn: -> { in_progress }, aliases: [] },
      stats: { fn: -> { FtgStats.new.run }, aliases: [] },
      start: { fn: -> { in_progress }, aliases: [] },
      stop: { fn: -> { in_progress }, aliases: [] },
      pause: { fn: -> { in_progress }, aliases: [] },
      resume: { fn: -> { in_progress }, aliases: [] },
      current: { fn: -> { in_progress }, aliases: [] },
      pop: { fn: -> { in_progress }, aliases: [] },
      edit: { fn: -> { edit }, aliases: [] },
      list: { fn: -> { in_progress }, aliases: [] },
      sync: { fn: -> { in_progress }, aliases: [] },
      config: { fn: -> { in_progress }, aliases: [] },
      touch: { fn: -> { in_progress }, aliases: [] },
      remove: { fn: -> { in_progress }, aliases: [:delete] },
      recap: { fn: -> { in_progress }, aliases: [:mailto] },
    }
  end

  def get_option(name)
    @options.keys.find { |opt| opt.to_s.start_with?(name) }
  end

  def fail(message = nil)
    STDERR.puts message if message
    exit(1)
  end

  def run
    help(1) if ARGV[0].nil?
    opt = get_option(ARGV[0])
    fail("Unknown option #{ARGV[0]}") if opt.nil?
    @options[opt][:fn].call
  end

  def help(exit_code = 0)
    help = <<-HELP
Usage: ftg <command> [arguments...]
By default, the day param is the current day.

Command list:
  help [<command>]                   Show this message
  stats [-d <day>]                   Show time stats
  start, stop, pause, resume <task>  Manage tasks
  current                            Show current task
  pop                                Stop current task and resume previous one
  edit <task>                        Manually edit times
  list                               List of tasks/meetings of the day
  sync [-d <day>]                    Sync times with jira and toggl
  config                             Show config files
  touch <task>                       Start and end a task right away
  remove <task>                      Delete a task
  recap                              Prepare a daily email recap
    HELP
    puts help
    exit(exit_code)
  end

  def edit
    Interactive.new.interactive_select
  end

  def redraw

  end

  def in_progress
    abort('in progress...')
  end
end


Ftg.new.run
