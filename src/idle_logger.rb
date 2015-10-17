
loop do
  idle_cmd = "echo $((`ioreg -c IOHIDSystem | sed -e '/HIDIdleTime/!{ d' -e 't' -e '}' -e 's/.* = //g' -e 'q'` / 1000000000))"
  idle_result = `#{idle_cmd}`
  date_result = `date +%s`
  
  `echo "#{idle_result.strip + '\t' + date_result.strip}" >> $HOME/.ftg/idle.log`
  sleep 10
end