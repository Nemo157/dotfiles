export svc=org.freedesktop.portal.Desktop
export obj=/org/freedesktop/portal/desktop
export int=org.freedesktop.portal.Settings
export ns=org.freedesktop.appearance
export key=color-scheme

scheme="$(
  for _ in {0..5}
  do
    (busctl -j --user call $svc $obj $int Read ss $ns $key  | jq -Mc '.data[0].data.data') && break
    sleep 1
  done
)"
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
