trap exit SIGINT
trap "echo -ne '\e[?1049l\e[?25h'" EXIT

options=("$@")
count=${#options[@]}
selected=0
max_url_width="$(
for option in "${options[@]}"
do
  IFS=$'\x1f' read -r url name <<< "$option"
  echo "${#url}"
done | sort -rn | head -n1
)"

echo -ne '\e[?25l\e[?1049h'

read -r height < <(tput lines cols)
height=$(( height - 1 ))

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

    IFS=$'\x1f' read -r url name <<< "${options[$index]}"
    if (( index == selected ))
    then
      printf ' %-*s  │  \e[95m%s\e[K\e[0m' "$max_url_width" "$url" "$name"
    else
      printf ' %-*s  │  %s\e[K\e[0m' "$max_url_width" "$url" "$name"
    fi

    echo
  done

  echo -ne "\e[48;5;18m\e[38;5;20m  [j/k: navigate]  [ctrl+u/d: half page]  [enter: open]  [e: edit & open]  [q: quit]  \e[K\e[0m"

  read -r -s -n1 key

  # read escape sequences for ctrl+u/d
  if [[ "$key" == $'\e' ]]
  then
    read -r -s -n4 -t 0.01 seq || true
    key="$key$seq"
  fi

  case "$key" in
    "k" )
      selected=$(( selected == 0 ? selected : selected - 1 ))
      ;;
    "j" )
      selected=$(( selected == count - 1 ? selected : selected + 1 ))
      ;;
    $'\x15' | $'\e[1;5A' )  # ctrl+u
      selected=$(( selected - height / 2 ))
      (( selected < 0 )) && selected=0
      ;;
    $'\x04' | $'\e[1;5B' )  # ctrl+d
      selected=$(( selected + height / 2 ))
      (( selected >= count )) && selected=$(( count - 1 ))
      ;;
    "e" )
      echo -ne '\e[?1049l\e[?25h'
      IFS=$'\x1f' read -r url name <<< "${options[$selected]}"
      if url="$(vipe 2>/dev/null <<< "$url")"
      then
        xdg-open "$url"
        if [ -n "$name" ]
        then
          tmux display-message "Opened $url ($name)"
        else
          tmux display-message "Opened $url"
        fi
        exit
      fi
      echo -ne '\e[?25l\e[?1049h'
      ;;
    "" )
      IFS=$'\x1f' read -r url name <<< "${options[$selected]}"
      xdg-open "$url"
      if [ -n "$name" ]
      then
        tmux display-message "Opened $url ($name)"
      else
        tmux display-message "Opened $url"
      fi
      ;&
    "q" | $'\e' )
      exit
      ;;
  esac
done
