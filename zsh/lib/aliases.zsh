## My custom aliases
alias cd..='cd ..'
alias ls='lsd'
alias ll='lsd -l'
alias lal='lsd -Al'
alias tree='lsd --tree'

if [ $commands[sudo] ]; then
  alias fu='sudo $( fc -ln -1 )'
fi

alias tmux_mutt='tmux new-window -t 9 mutt'
alias tmux_irssi='tmux new-window -t 10 irssi'
alias ytop='ytop -c ansi-8'
