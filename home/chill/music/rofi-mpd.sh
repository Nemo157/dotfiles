run() {
  cmd="$1"
  shift
  printf '\e[34m$ %q' "$cmd" >&2
  printf ' %q' "$@" >&2
  printf '\e[0m\n' >&2
  "$cmd" "$@"
}

if ! [[ -v ROFI_RETV ]]
then
  run exec rofi -show mpd -modes "mpd:bash $0"
elif [ "$ROFI_RETV" = 0 ]
then
  # shellcheck disable=SC2016
  run beet ls -a -f '$albumartists' | run sed $'s/\\\\\xe2\x90\x80/\\n/g' | sort -u
elif ! [[ -v ROFI_INFO ]]
then
  albumartist="$1"
  albums=("$(run beet ls -a -f $'$year\x1c$month\x1c$day\x1c$album\x1c$albumartist\x1c$artpath' "albumartists:$albumartist" | sort)")

  len=0
  while IFS=$'\x1c' read -r year month day album albumartist artpath
  do
    if (( ${#albumartist} > len ))
    then
      len=${#albumartist}
    fi
  done <<<"${albums[*]}"

  while IFS=$'\x1c' read -r year month day album albumartist artpath
  do
    run printf '%-*s  ¦  [%s] %s\0icon\x1f%s\x1finfo\x1f%s\x1c%s\n' "$len" "$albumartist" "$year" "$album" "$artpath" "$albumartist" "$album"
  done <<<"${albums[*]}"
else
  IFS=$'\x1c' read -r albumartist album <<<"$ROFI_INFO"

  run mpc clear >&2
  run mpc findadd albumartist "$albumartist" album "$album" >&2
  run mpc play >&2
fi
