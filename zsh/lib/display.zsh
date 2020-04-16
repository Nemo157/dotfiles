## Setup colour schemes
if [ $commands[dircolors] ]; then
  if [[ -f ~/.dir_colors ]]; then
    eval $(dircolors -b ~/.dir_colors)
  elif [[ -f /etc/DIR_COLORS ]]; then
    eval $(dircolors -b /etc/DIR_COLORS)
  fi
fi

# Setup the ls color option depending on Linux or BSD version ls
ls --color -d . &>/dev/null 2>&1 && alias ls='ls -F --color=auto' || alias ls='ls -FG'
