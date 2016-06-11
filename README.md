# .ftg

Utility to do time tracking based on time spent in git branches.

The main usage is the following one:

 - At the end of the day, send a daily recap
 - Time spend in branches is already set
 - Move around with arrows, delete task with backspace, validate with enter

Many more commands are available. Run `ftg help` to view them.

(click image below to play video)

[![ftg demo](http://img.youtube.com/vi/hbOyWkfL9tA/0.jpg)](https://www.youtube.com/watch?v=hbOyWkfL9tA)

## Requirements
- MacOSX
- [OhMyZsh](https://github.com/robbyrussell/oh-my-zsh])
- ruby

## How to install
- Add the following at the end of your .zshrc:
````shell
####################################################### FTG
  ftg_heartbeat () {
    command="$(fc -n -e - -l -1)"
    c_alias="`alias $command`"
    c_alias=${c_alias:-no_alias}
    log_file="$HOME/.ftg/log/commands.log"
    branch="`git rev-parse --abbrev-ref HEAD`"
    branch=${branch:-no_branch}

    echo "$USER\t$command\t$c_alias\t`pwd`\t$branch\t`date +%s`" >> "$log_file"

    case "$(ps aux | grep '[i]dle_logger' | wc -l | awk {'print $1'})" in
      '0')  ruby $HOME/.ftg/lib/idle_logger.rb &
    ;;
      '1')  # all good
    ;;
      *)  echo "Problem with restarting idle_logger. See ~/.zshrc"
    ;;
    esac
  }

  precmd () {
    (ftg_heartbeat &) 2> /dev/null
#> /dev/null
  }

alias ftg="ruby ~/.ftg/lib/ftg/ftg.rb"
####################################################### END FTG
````
- `cd ~`
- `git clone git@github.com:pinouchon/.ftg.git`
- Restart your shell
- ???
- profit

