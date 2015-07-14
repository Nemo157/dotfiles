## If running interactively, do stuff
if [[ $- == *i* ]] ; then

## don't put duplicate lines in the history. See bash(1) for more options
HISTCONTROL=ignoreboth

## append to the history file, don't overwrite it
shopt -s histappend

## check the window size after each command and, if necessary,
## update the values of LINES and COLUMNS.
shopt -s checkwinsize

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

fi
