## If not running interactively, don't do anything
if [[ -n "$PS1" ]] ; then

## don't put duplicate lines in the history. See bash(1) for more options
HISTCONTROL=ignoreboth

## append to the history file, don't overwrite it
shopt -s histappend

## check the window size after each command and, if necessary,
## update the values of LINES and COLUMNS.
shopt -s checkwinsize

PS1='[\u@\h \W]'

## enable color support of ls and also add handy aliases
alias grep='grep --color=auto'
alias fgrep='fgrep --color=auto'
alias egrep='egrep --color=auto'
alias ls='ls --color=auto'
alias ll='ls -al'

## Enable programmable completion features
if [ -f /etc/bash_completion ] && ! shopt -oq posix; then
    . /etc/bash_completion
fi

## ^DEL = delete word to the right.
bind '"^[[3;5~": kill-word'

## ^BACKSPACE = delete word to the left.
##   Cannot be used currently as ^BACKSPACE = BACKSPACE = 
#bind '"{{{{ctrl-backspace}}}}": backword-kill-word'

## ^LEFT and ^RIGHT move a word at a time.
bind '"^[[1;5C": forward-word'
bind '"^[[1;5D": backward-word'

## Add required directories to PATH.
if [ -d "/home/nemo157/sources/gnuarm-4.0.2/bin" ]; then
  export "PATH=$PATH:/home/nemo157/sources/gnuarm-4.0.2/bin"
fi

if [ -d "/home/nemo157/sources/depot_tools" ]; then
  export "PATH=$PATH:/home/nemo157/sources/depot_tools"
fi

if [ -d "/home/nemo157/.gem/ruby/1.8/bin" ]; then
  export "PATH=$PATH:/home/nemo157/.gem/ruby/1.8/bin"
fi

if [ -d "/usr/local/avr/bin" ]; then
  export "PATH=$PATH:/usr/local/avr/bin"
fi

if [ -d "/home/cosc/student/wgl18/gnuarm-4.0.2/bin/" ]; then
  export "PATH=$PATH:/home/cosc/student/wgl18/gnuarm-4.0.2/bin/"
fi

alias inet='telnet ienabler.canterbury.ac.nz 259'
alias mobile-chromium='chromium-browser --user-agent="Mozilla/5.0 (iPhone; U; CPU iPhone OS 3_0 like Mac OS X; en-us) AppleWebKit/420.1 (KHTML, like Gecko) Version/3.0 Mobile/1A542a Safari/419.3"'

fi

[[ -d $HOME/.rvm/bin ]] && PATH=$PATH:$HOME/.rvm/bin # Add RVM to PATH for scripting
