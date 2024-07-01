format='{{status}}{{position}}'
script='
  . / ""
  | {
      state: (.[0] | ascii_downcase),
      position: (.[1] | tonumber / 1000000),
    }
'
playerctl -p mpd metadata -f "$format" -F | jq --unbuffered -RMc "$script"
