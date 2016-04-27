## My custom aliases
alias cd..='cd ..'
alias ls='ls -h'
alias ll='ls -l'
alias lal='ls -al'
if [[ -x $(which gdu) ]]; then
  alias sizes='gdu -hs ./* | gsort -hr | head'
else
  alias sizes='du -hs ./* | sort -hr | head'
fi
alias man=run-help

if [[ -x $(which sudo) ]] alias fu='sudo $( fc -ln -1 )'

alias tmux_mutt='tmux new-window -t 9 env EDITOR=vim mutt'
alias tmux_irssi='tmux new-window -t 10 irssi'
