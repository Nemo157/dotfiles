strip_unbalanced_parens() {
  while IFS= read -r url
  do
    while [[ "$url" == *')' ]]
    do
      opens="${url//[^(]/}"
      closes="${url//[^)]/}"
      if (( ${#closes} > ${#opens} ))
      then
        url="${url%')'}"
      else
        break
      fi
    done
    echo "$url"
  done
}

filter_bare() {
  rg --only-matching 'https?://([-a-zA-Z0-9@:%._\+~#=]{1,256}\.[a-zA-Z0-9]{2,6}\b([-a-zA-Z0-9()@:%_\+.~#?&//=]*)|\[[0-9a-f:]+\](:[0-9]+)?)' \
    | strip_unbalanced_parens \
    || true
}

filter_osc8() {
  # shellcheck disable=SC1003
  rg --only-matching '\x1b\]8;[^;]*;([^\x1b]+)\x1b\\(.*?)\x1b\]8;;\x1b\\' --replace $'$1\x1f$2' || true
}

capture_urls() {
  start="$(tmux display-message -p '#{?#{==:#{pane_mode},copy-mode},-#{scroll_position},0}')"
  end="$(tmux display-message -p '#{?#{==:#{pane_mode},copy-mode},#{e|-:#{pane_height},#{scroll_position}},#{pane_height}}')"
  (
    tmux capture-pane -Jp -S "$start" -E "$end" | filter_bare
    tmux capture-pane -Jpe -S "$start" -E "$end" | filter_osc8
  )
}

readarray -t urls < <(capture_urls)

if ! [[ -v urls ]]
then
  tmux display-message "No urls found"
  exit 0
fi

echo "urls" >&2
printf "%q\n" "${urls[@]}" >&2

# deduplicate while preserving order, taking the last name for each url
declare -A mapped
declare -a order
for entry in "${urls[@]}"
do
  IFS=$'\x1f' read -r url name <<< "$entry"
  if [[ ! -v mapped["$url"] ]]
  then
    order+=("$url")
  fi
  mapped["$url"]="$name"
done

readarray -t urls < <(
  for url in "${order[@]}"
  do
    printf '%s\x1f%s\n' "$url" "${mapped[$url]}"
  done
)

echo "clean urls" >&2
printf "%q\n" "${urls[@]}" >&2

tmux display-popup -E -T 'Open url' "$TMUX_URLVIEW_POPUP" "${urls[@]}"
