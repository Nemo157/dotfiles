get-info() {
  curl -s https://api.listenbrainz.org/1/user/Nemo157/playing-now | jq -Mc '
    .payload.listens[].track_metadata
    | {
      artist: .artist_name,
      release: .release_name,
      track: .track_name,
      number: .additional_info.tracknumber,
      mbid: .additional_info.release_mbid,
    }
  '
}

prev=
info() {
  if new="$(get-info)" && [ "$prev" != "$new" ]
  then
    prev="$new"
    echo "$new"
  fi
}

while true
do
  info
  sleep 5
done
