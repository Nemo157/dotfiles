trap exit SIGINT
trap "echo -ne '\e[?1049l\e[?25h'" EXIT

options=("$@")
count=${#options[@]}
selected=0

echo -ne '\e[?25l\e[?1049h'

height=$(( $(tput lines) - 1 ))
cols=$(tput cols)

# 3 (left pad + marker) + 1 (space) + url + 5 (  │  ) + name = cols
# Split available space in half for url and name columns
available=$(( cols - 3 - 1 - 5 ))
max_url_width=$(( available / 2 ))
max_name_width=$(( available - max_url_width ))

truncate() {
  local str="$1" max="$2"
  local len
  if (( ${#str} > max )); then
    str="${str:0:$(( max - 1 ))}…"
    len=$max
  else
    len=${#str}
  fi
  local pad=$(( max - len ))
  printf '%s%*s' "$str" "$pad" ""
}

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

  for (( i = 0 ; i < height ; i++ ))
  do
    index=$(( offset + i ))
    if (( index < count ))
    then
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
      turl="$(truncate "$url" "$max_url_width")"
      tname="$(truncate "$name" "$max_name_width")"
      if (( index == selected ))
      then
        printf ' %s  │  \e[95m%s\e[K\e[0m' "$turl" "$tname"
      else
        printf ' %s  │  %s\e[K\e[0m' "$turl" "$tname"
      fi
    else
      printf '    %*s  │\e[K' "$max_url_width" ""
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
