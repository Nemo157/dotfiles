format='{{xesam:albumArtist}}{{xesam:artist}}{{xesam:album}}{{xesam:title}}{{mpris:length}}{{mpris:artUrl}}'
script='
  def ornull: if length > 0 then . else null end;
  . / ""
  | {
      albumartist: .[0] | ornull,
      artist: .[1] | ornull,
      album: .[2] | ornull,
      title: .[3] | ornull,
      duration: (.[4] | if length > 0 then tonumber / 1000000 else 0 end),
      albumart: (.[5] | sub("file://"; "") | ornull),
    }
'
playerctl -p mpd metadata -f "$format" -F | jq --unbuffered -RMc "$script"
