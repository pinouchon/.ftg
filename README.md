# .ftg

## f*** toggl
Utility that you can use so you can close toggl.

## Example usage
````shell
$> ftg
sample output here
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
- `cd ~``
- `git clone git@github.com:pinouchon/.ftg.git`
- Restart your shell
- ???
- profit
