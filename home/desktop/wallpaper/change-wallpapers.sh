scheme="$(appearance-watcher --once | jq -r '.["color-scheme"]')"
op="$([ "$scheme" = "dark" ] && echo -le || echo -ge)"

echo "color-scheme $scheme => op $op" >&2

read -r -a fd_filter <<< "${WALLPAPER_FD_ARGS:-}"

wallpaper() {
  fd -Ltf . "${WALLPAPER_DIR:-$HOME/Wallpapers}" "${fd_filter[@]}" | shuf -n10 | while read -r img
  do
    echo "$img" >&2
    median="$(magick "$img"'[0]' -format '%[fx:trunc(median * 100)]' info:)"
    echo "median $median/100" >&2
    if test "$median" "$op" 40
    then
      echo "$img"
      break
    else
      echo "outside brightness threshold" >&2
    fi
  done
}

get-monitors() {
  niri msg -j outputs | jq -r '.[] | select (.current_mode) | "\(false) \(.name)"'
}

get-monitors | while read -r solitary monitor
do
  if [[ "$solitary" == "false" ]]
  then
    img="$(wallpaper)"
    if [ -n "$img" ]
    then
      echo "selected $img for $monitor" >&2
      set-wallpaper "$monitor" "$img"
    else
      echo "failed to select image for $monitor" >&2
    fi
  else
    echo "skipping $monitor with solitary client $solitary" >&2
  fi
done
