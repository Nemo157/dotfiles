## My custom aliases
alias cd..='cd ..'
alias ls='ls -h'
alias ll='ls -l'
alias lal='ls -al'
alias inet='telnet ienabler.canterbury.ac.nz 259'
alias tree='tree -A'
alias rdmath='rdesktop -g1440x850 -z -xm -u wgl18 mathlab1.math.canterbury.ac.nz'
alias sizes='gdu -hs ./* | gsort -hr | head'
alias pwd='dirs -v'

if [[ -x $(which sudo) ]] alias fu='sudo $( fc -ln -1 )'
