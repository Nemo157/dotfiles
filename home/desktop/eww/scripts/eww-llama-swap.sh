HOST="http://127.0.0.1:8083"

last=""

emit() {
  if [[ "$1" != "$last" ]]; then
    last="$1"
    printf '%s\n' "$1"
  fi
}

fetch_state() {
  curl -sf -m 2 "$HOST/running" |
    jq -c '.running | {available: true, running: (length > 0), model: (if length > 0 then .[0].model else null end)}'
}

while true; do
  if ! state=$(fetch_state); then
    emit '{"available":false,"running":false,"model":null}'
    sleep 60
    continue
  fi
  emit "$state"
  # stream llama-swap events; refetch state on modelStatus events
  curl -sfN --no-buffer "$HOST/api/events" |
    while read -r event; do
      [[ "$event" == *'"type":"modelStatus"'* ]] || continue
      state=$(fetch_state) || break
      emit "$state"
    done
  # stream dropped; brief pause before reconnecting
  sleep 2
done
