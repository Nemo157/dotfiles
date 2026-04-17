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
  run beet export -fjsonlines -ialbumartists -a | jq -r '(.albumartists / "\\␀") .[]' | sort -u
elif ! [[ -v ROFI_INFO ]]
then
  albumartist="$1"
  albums="$(run beet export -fjson -iyear,month,day,album,albumartist,artpath -a "albumartists:$albumartist")"

  len="$(jq -r '[.[].albumartist | length] | max' <<<"$albums")"
  jq --argjson len "$len" <<<"$albums" -r '
    def rpad(n): tostring | . + (n - length) * " ";
    sort_by([.year, .month, .day]) .[]
      | "\(.albumartist | rpad($len)) ¦  [\(.year)] \(.album)\u0000icon\u001f\(.artpath)\u001finfo\u001f\(.albumartist)\u001c\(.album)"
  '
else
  IFS=$'\x1c' read -r albumartist album <<<"$ROFI_INFO"

  run mpc clear >&2
  run mpc findadd albumartist "$albumartist" album "$album" >&2
  run mpc play >&2
fi
