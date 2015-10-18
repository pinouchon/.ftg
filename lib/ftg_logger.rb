class FtgLogger

  def initialize(ftg_dir)
    @ftg_dir = ftg_dir
    @log_file = "#{ftg_dir}/log/ftg.log"
  end

  def add_log(command, task)
    lines = [command, task, Time.now.getutc.to_i]
    `echo "#{lines.join('\t')}" >> #{@log_file}`
  end

  def remove_all_logs
    `echo "" > #{@log_file}`
  end

  def remove_logs(name)
    count = 0
    logs = get_logs
    logs.keep_if do |log|
      cond = log[:task_name] != name || log[:timestamp].to_i <= Time.now.to_i - 24*3600
      count += 1 unless cond
      cond
    end

    File.open(@log_file, 'w') do |f|
      f.write(logs.map{|l| l.values.join("\t")}.join("\n") + "\n")
    end

    puts "Removed #{count} entries"
  end

  def get_logs
    File.open(@log_file, File::RDONLY|File::CREAT) do |file|
      file.read.split("\n").map do |e|
        parts = e.split("\t")
        { command: parts[0], task_name: parts[1], timestamp: parts[2] }
      end
    end
  end

  def on_pause?
    unclosed_logs = get_unclosed_logs
    unclosed_logs[0] && unclosed_logs[0][:task_name] == 'pause'
  end

  def get_unclosed_logs
    unclosed_logs = []
    closed = {}
    get_logs.reverse.each do |log|
      if log[:command] == 'ftg_stop'
        closed[log[:task_name]] = true
      end
      if log[:command] == 'ftg_start' && !closed[log[:task_name]]
        unclosed_logs << log
      end
    end
    unclosed_logs
  end

  def update_current
    current = ''
    current_logs = get_unclosed_logs
    current = current_logs[0][:task_name] unless current_logs.empty?
    `echo "#{current}" > #{@ftg_dir}/current.txt`
  end
end