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

    IFS=$'\x1f' read -r url name <<< "${options[$index]}"
    if (( index == selected ))
    then
      printf ' %-*s  │  \e[95m%s\e[K\e[0m' "$max_url_width" "$url" "$name"
    else
      printf ' %-*s  │  %s\e[K\e[0m' "$max_url_width" "$url" "$name"
    fi

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
    "e" )
      echo -ne '\e[?1049l\e[?25h'
      IFS=$'\x1f' read -r url name <<< "${options[$selected]}"
      if url="$(vipe 2>/dev/null <<< "$url")"
      then
        options["$selected"]="$(printf '%s\x1f%s\n' "$url" "$name")"
      fi
      if (( ${#url} > max_url_width ))
      then
        max_url_width=${#url}
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
