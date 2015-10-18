class FtgLogger

  def initialize(log_file)
    @log_file = log_file
  end

  def add_log(command, task)
    lines = [command, task, Time.now.getutc.to_i]
    `echo "#{lines.join('\t')}" >> #{@log_file}`
  end

  def get_logs
    File.open(@log_file, 'r') do |file|
      file.read.split("\n").map do |e|
        parts = e.split("\t")
        { command: parts[0], task_name: parts[1], timestamp: parts[2] }
      end
    end
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
end