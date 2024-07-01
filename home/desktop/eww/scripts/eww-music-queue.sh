playerctl -p mpd metadata -f '{{xesam:title}}}' -F | while read -r; do
  {
    mpc status '%songpos%\f%length%' | jq -R '
      . / "\f"
        | (.[0] | tonumber) as $position
        | (.[1] | tonumber) as $length
        | {
          position: $position,
          length: $length,
        }
    ' || true
  } | jq -sMc 'map(to_entries) | flatten | from_entries'
done
