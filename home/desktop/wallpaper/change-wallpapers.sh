scheme="$(appearance-watcher --once | jq -r '.["color-scheme"]')"
op="$([ "$scheme" = "dark" ] && echo -le || echo -ge)"

echo "color-scheme $scheme => op $op" >&2

wallpaper() {
  fd -Ltf . ~/Wallpapers | shuf -n10 | while read -r img
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

if [[ -v HYPRLAND_INSTANCE_SIGNATURE ]]
then
  get-monitors() {
    hyprctl monitors -j | jq -r '.[] | "\(.solitary == 1) \(.name)"'
  }
fi

if [[ -v NIRI_SOCKET ]]
then
  get-monitors() {
    niri msg -j outputs | jq -r 'keys.[] | "\(false) \(.)"'
  }
fi

get-monitors | while read -r solitary monitor
do
  if [[ "$solitary" == "false" ]]
  then
    img="$(wallpaper)"
    echo "selected $img for $monitor" >&2
    set-wallpaper "$monitor" "$img"
  else
    echo "skipping $monitor with solitary client $solitary" >&2
  fi
done
