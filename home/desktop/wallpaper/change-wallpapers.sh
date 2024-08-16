scheme="$(appearance-watcher --once | jq -r '.["color-scheme"]')"
op="$([ "$scheme" = 1 ] && echo -le || echo -ge)"

echo "color-scheme $scheme => op $op" >&2

wallpaper() {
  fd -tf . ~/Wallpapers | shuf -n10 | while read -r img
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

hyprctl monitors -j | jq -r '.[].name' | while read -r monitor
do
  img="$(wallpaper)"
  echo "selected $img" >&2
  set-wallpaper "$monitor" "$img"
done
