class Interactive
  KEY_TOP = "\e[A"
  KEY_RIGHT = "\e[C"
  KEY_DOWN = "\e[B"
  KEY_LEFT = "\e[D"
  KEY_BACKSPACE = "\x7F"
  KEY_ENTER = "\r"
  KEY_CTRL_C = "\x03"
  KEY_TAB = "\t"
  KEY_ESCAPE = "\e"

  SEQ_ERASE_LEFT = "\e[D"
  SEQ_ERASE_TO_END_OF_LINE = "\033[K"

  def initialize
    @term_width = `/usr/bin/env tput cols`.to_i
    @formatter = TaskFormatter.new

    if @term_width < @formatter.max_width
      message = " Your terminal must be at least #{@formatter.max_width} columns wide "
      STDERR.puts('<' + message.
                    rjust(@formatter.max_width + 1 - message.length / 2, '-').
                    ljust(@formatter.max_width - 2, '-') + '>')
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

  def print_tasks
    task_len = TaskFormatter.max_length(@tasks)

    puts @header
    @tasks.each_with_index do |task, i|
      @formatter.format(task, task_len)

      print "\e[47m" + "\e[30m" if i == @task_selected
      print @formatter.line_for_interactive
      print "\e[0m" if i == @task_selected
      print '  ' + @formatter.sync_status
      print "\033[K"
      puts ''
    end
    total_time = Utils.format_time(@tasks.map(&:duration).reduce(:+))
    puts "\e[100m  #{''.ljust(task_len, ' ')} #{total_time}  #{''.rjust(@formatter.bar_size, ' ')}  \e[0m\033[K"

    puts "\033[K"
    print "\033[#{@tasks.length + 3}A"
  end


  def interactive_edit(tasks)
    @tasks = tasks
    @deleted_tasks = []
    @header = '2015-06-03  ' + '[↑|↓] navigate, [⇽|⇾] adjust time, [⇐ ] remove, [↵ |q] save, [esc] cancel'.grey

    @task_selected = 0

    loop do
      print_tasks
      input = read_char

      # puts input
      exit if [KEY_CTRL_C, KEY_ESCAPE].include? input
      return @deleted_tasks if [KEY_ENTER, 'q'].include? input

      top_down = { KEY_DOWN => +1, KEY_TOP => -1 }
      if top_down.keys.include? input
        @task_selected += top_down[input]
        @task_selected %= @tasks.length
      end
      left_right = { KEY_RIGHT => +300, KEY_LEFT => -300 }
      if left_right.keys.include? input
        time = @tasks[@task_selected].duration
        time = [time - (time % 300) + left_right[input], 0].max
        @tasks[@task_selected].duration = time
        @tasks[@task_selected].edited_at = Time.now
      end
      if input == KEY_BACKSPACE
        next if @tasks.length <= 1
        @tasks[@task_selected].deleted_at = Time.now
        @deleted_tasks << @tasks[@task_selected]
        @tasks.delete_at(@task_selected)
        @task_selected -= 1 if @task_selected == @tasks.length
        @task_selected %= @tasks.length
      end
    end

  end
end