trap exit SIGINT
trap "echo -ne '\e[?1049l\e[?25h'" EXIT

options=("$@")
count=${#options[@]}
selected=0

echo -ne '\e[?25l\e[?1049h'

read -r height < <(tput lines cols)
# height=$(( height - 2 ))

while true
do
  echo -ne "\e[H"

  offset=$(( selected - height / 2 ))
  if (( offset < 0 ))
  then
    offset=0
  elif (( offset > count - height ))
  then
    offset=$(( count - height ))
  fi

  for (( i = 0 ; i < height && offset + i < count ; i++ ))
  do
    index=$(( offset + i ))
    if (( index == selected ))
    then
      echo -ne "\e[40m  \e[95m»\e[39m"
    elif (( i == 0 && index > 0 ))
    then
      echo -ne "  \e[95m▲\e[39m"
    elif (( i == height - 1 && index < count - 1 ))
    then
      echo -ne "  \e[95m▼\e[39m"
    else
      echo -ne "   "
    fi
    echo -ne "  ${options[$index]}\e[K\e[0m"
    if (( i != height - 1 ))
    then
      echo
    fi
  done

  read -r -s -n1 key

  case "$key" in
    "k" )
      selected=$(( selected == 0 ? selected : selected - 1 ))
      ;;
    "j" )
      selected=$(( selected == count - 1 ? selected : selected + 1 ))
      ;;
    "" )
      xdg-open "${options[$selected]}"
      tmux display-message "Opened ${options[$selected]}"
      ;&
    "q" | $'\e' )
      exit
      ;;
  esac
done
