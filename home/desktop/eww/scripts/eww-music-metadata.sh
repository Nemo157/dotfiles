# fields are separated by form feed, which shouldn't appear in the metadata itself
sep=$'\f'
format="{{xesam:albumArtist}}$sep{{xesam:artist}}$sep{{xesam:album}}$sep{{xesam:title}}$sep{{mpris:length}}$sep{{mpris:artUrl}}"
script='
  def ornull: if length > 0 then . else null end;
  . / $sep
  | {
      albumartist: .[0] | ornull,
      artist: .[1] | ornull,
      album: .[2] | ornull,
      title: .[3] | ornull,
      duration: (.[4] | if length > 0 then tonumber / 1000000 else 0 end),
      albumart: (.[5] | sub("file://"; "") | ornull),
    }
'
playerctl -p mpd metadata -f "$format" -F | jq --unbuffered -RMc --arg sep "$sep" "$script"
