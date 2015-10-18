module FtgOptions
  def get_option(names)
    ARGV.each_with_index do |opt_name, i|
      return (ARGV[i + 1] || 1) if names.include?(opt_name)
    end
    nil
  end

  # day, not gay
  def day_option
    day_option = get_option(['-d', '--day'])
    day_option ||= '0'

    Utils.is_integer?(day_option) ?
      Time.at(Time.now.to_i - day_option.to_i * 86400).strftime('%F') :
      Date.parse(day_option).strftime('%F')
  end

  def get_command(name)
    @commands.find { |cmd_name, _| cmd_name.to_s.start_with?(name) } ||
      @commands.find { |_, cmd| cmd[:aliases] && cmd[:aliases].any? { |a| a.to_s.start_with?(name) } }
  end

  def fail(message = nil)
    STDERR.puts message if message
    exit(1)
  end
end