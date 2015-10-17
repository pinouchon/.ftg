class Interactive
  KEY_TOP = "\e[A"
  KEY_RIGHT = "\e[C"
  KEY_DOWN = "\e[B"
  KEY_LEFT = "\e[D"
  KEY_BACKSPACE = "\x7F"
  KEY_ENTER = "\r"
  KEY_CTRL_C = "\x03"
  KEY_TAB = "\t"

  SEQ_ERASE_LEFT = "\e[D"
  SEQ_ERASE_TO_END_OF_LINE = "\033[K"

  BAR_SIZE = 40
  MAX_LEN = 94

  def initialize
    @term_width = `/usr/bin/env tput cols`.to_i

    if @term_width < MAX_LEN
      message = " Your terminal must be at least #{MAX_LEN} columns wide "
      STDERR.puts('<' + message.
                    rjust(MAX_LEN + 1 - message.length / 2, '-').
                    ljust(MAX_LEN - 2, '-') + '>')
      exit(1)
    end
  end

  def read_char
    begin
      # save previous state of stty
      old_state = `stty -g`
      # disable echoing and enable raw (not having to press enter)
      system "stty raw -echo"
      c = STDIN.getc.chr
      # gather next two characters of special keys
      if (c=="\e")
        extra_thread = Thread.new {
          c = c + STDIN.getc.chr
          c = c + STDIN.getc.chr
        }
        # wait just long enough for special keys to get swallowed
        extra_thread.join(0.00001)
        # kill thread so not-so-long special keys don't wait on getc
        extra_thread.kill
      end
    rescue => ex
      puts "#{ex.class}: #{ex.message}"
      puts ex.backtrace
    ensure
      # restore previous state of stty
      system "stty #{old_state}"
    end
    return c
  end

  def format_time(secs)
    '%02sh %02dm' % [secs / 60, secs % 60]
  end

  def task_len
    [@tasks.map { |e| e[:name].length }.max, 60].min
  end

  def print_tasks
    task_len = self.task_len

    puts @header
    @tasks.each_with_index do |task, i|
      time_len = [task[:time] / 5, BAR_SIZE].min
      if time_len >= BAR_SIZE
        time_bar = "[#{('=' * (time_len - 2)) + '...'}"
      else
        time_bar = "[#{('=' * time_len).ljust(BAR_SIZE, ' ')}]"
      end
      task_formatted = task[:name][0, task_len].ljust(task_len, ' ')
      sync_status = task[:sync] ? '✔' : '✘'
      line = "  #{task_formatted} #{format_time(task[:time])}  #{time_bar}"

      print "\e[47m" + "\e[30m" if i == @task_selected
      print line #[0..@term_width - 1]
      print "\e[0m" if i == @task_selected
      print '  ' + sync_status
      print "\033[K"
      puts ''
    end
    total_time = format_time(@tasks.map { |t| t[:time] }.reduce(:+))
    puts "\e[100m  #{''.ljust(task_len, ' ')} #{total_time}  #{''.rjust(BAR_SIZE, ' ')}  \e[0m\033[K"

    puts "\033[K"
    print "\033[#{@tasks.length + 3}A"
  end


  def interactive_select

    @header = '2015-06-03  ' + '[↑|↓] navigate, [⇽|⇾] adjust time, [⇐ ] remove, [↵ ] save'.grey
    @tasks = [
      { name: 'sprint/JT-1234-some-desc', time: 78, sync: true },
      { name: 'meetings/standup', time: 10, sync: false },
      { name: 'sprint/JT-1243-other-long-description', time: 23, sync: false },
      { name: 'sprint/JT-1222-desc', time: 220, sync: false },
      { name: 'sprint/JT-2423-desc', time: 23, sync: false },
      { name: 'sprint/JT-1923-hello', time: 110, sync: true },
      { name: 'sprint/JT-1973-some-desc-toto', time: 5, sync: false },
    ]

    @task_selected = 0

    loop do
      print_tasks
      input = read_char

      # puts input
      exit if [KEY_CTRL_C, KEY_ENTER, 'q'].include? input
      top_down = { KEY_DOWN => +1, KEY_TOP => -1 }
      if top_down.keys.include? input
        @task_selected += top_down[input]
        @task_selected %= @tasks.length
      end
      left_right = { KEY_RIGHT => +5, KEY_LEFT => -5 }
      if left_right.keys.include? input
        time = @tasks[@task_selected][:time]
        time = [time - (time % 5) + left_right[input], 0].max
        @tasks[@task_selected][:time] = time
      end
      if input == KEY_BACKSPACE
        next if @tasks.length <= 1
        @tasks.delete_at(@task_selected)
        @task_selected -= 1 if @task_selected == @tasks.length
        @task_selected %= @tasks.length
      end
    end

  end
end