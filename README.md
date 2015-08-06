# .ftg

## f*** toggl
Utility that you can use so you can close toggl.

## Example usage
````shell
$> ftg
2015-08-05:
  no_branch: 00:02:40 (and 00:00:00 idle)
  feature/jira-1323-ssl-redirect: 03:12:20 (and 00:50:40 idle)
  feature/jira-1056-checkout-spinner: 00:56:10 (and 00:02:40 idle)
  feature/jira-1126-remove-unused-css: 00:09:30 (and 00:00:00 idle)
  develop: 00:13:30 (and 00:00:00 idle)
  meetings/standup: 00:05:00 (and 00:07:50 idle)
2015-08-06:
  no_branch: 00:02:40 (and 00:00:00 idle)
  feature/jira-1402-responsive-header: 01:12:20 (and 00:13:20 idle)
  feature/jira-1402-assets-upload-task: 02:32:20 (and 00:20:20 idle)
  feature/jira-1056-remove-newrelic-warnings: 00:43:10 (and 00:00:00 idle)
  master: 00:01:30 (and 00:00:00 idle)
  develop: 00:01:30 (and 00:00:00 idle)
  meetings: 00:40:00 (and 00:12:50 idle)
  meetings/standup: 00:05:00 (and 00:12:50 idle)
````


## Requirements
- MacOSX
- [OhMyZsh](https://github.com/robbyrussell/oh-my-zsh])
- ruby

## How to install
- Add the following at the end of your .zshrc:
````shell
###### FTG
 precmd () {
    command="$(fc -n -e - -l -1)"
    c_alias="`alias $command`"
    c_alias=${c_alias:-no_alias}
    log_file="$HOME/.ftg/commands.log"
    branch="$(current_branch)"
    branch=${branch:-no_branch}
    echo "$USER\t$command\t$c_alias\t`pwd`\t$branch\t`date +%s`" >> "$log_file"
}
kill $(ps -x | grep '[i]dle_logger.rb' | awk '{print $1}')
ruby $HOME/.ftg/idle_logger.rb &
alias ftg="ruby ~/.ftg/ftg_stats.rb"
````
- `cd ~`
- `git clone git@github.com:pinouchon/.ftg.git`
- Restart your shell
- ???
- profit
