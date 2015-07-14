## Set colour term if in gnome-terminal
if [[ "$COLORTERM" == "gnome-terminal" ]] then
  export TERM='xterm-256color'
fi
