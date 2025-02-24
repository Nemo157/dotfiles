filter_bare() {
  rg --only-matching 'https?://([-a-zA-Z0-9@:%._\+~#=]{1,256}\.[a-zA-Z0-9()]{2,6}\b([-a-zA-Z0-9()@:%_\+.~#?&//=]*)|\[[0-9a-f:]+\](:[0-9]+)?)'
}

filter_osc8() {
  # shellcheck disable=SC1003
  rg --only-matching '\x1b\]8;[^;]*;([^\x1b]+)\x1b\\(.*?)\x1b\]8;;\x1b\\' --replace $'$1\x1f$2'
}

capture_urls() {
  start="$(tmux display-message -p '#{?#{==:#{pane_mode},copy-mode},-#{scroll_position},0}')"
  end="$(tmux display-message -p '#{?#{==:#{pane_mode},copy-mode},#{e|-:#{pane_height},#{scroll_position}},#{pane_height}}')"
  (
    tmux capture-pane -Jp -S "$start" -E "$end" | filter_bare
    tmux capture-pane -Jpe -S "$start" -E "$end" | filter_osc8
  ) | sort -u
}

readarray -t urls < <(capture_urls)

if ! [[ -v urls ]]
then
  tmux display-message "No urls found"
  return
fi

echo "urls" >&2
printf "%q\n" "${urls[@]}" >&2

# sort -u takes care of exact duplicates, but we want to also remove duplicates
# with different additional info, taking the last value for each url will do,
# any info-less version will be first

declare -A mapped
for url in "${urls[@]}"
do
  IFS=$'\x1f' read -r url name <<< "$url"
  mapped["$url"]="$name"
done

readarray -t urls < <(
  for url in "${!mapped[@]}"
  do
    printf '%s\x1f%s\n' "$url" "${mapped[$url]}"
  done | sort
)

echo "clean urls" >&2
printf "%q\n" "${urls[@]}" >&2

tmux display-popup -E -T 'Open url' "$(which tmux-urlview-popup)" "${urls[@]}"
