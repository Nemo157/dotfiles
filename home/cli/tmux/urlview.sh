capture() {
  start="$(tmux display-message -p '#{?#{==:#{pane_mode},copy-mode},-#{scroll_position},0}')"
  end="$(tmux display-message -p '#{?#{==:#{pane_mode},copy-mode},#{e|-:#{pane_height},#{scroll_position}},#{pane_height}}')"
  tmux capture-pane -Jpe -S "$start" -E "$end"
}

filter_bare() {
  rg --only-matching 'https?://[-a-zA-Z0-9@:%._\+~#=]{1,256}\.[a-zA-Z0-9()]{2,6}\b([-a-zA-Z0-9()@:%_\+.~#?&//=]*)'
}

filter_osc8() {
  rg --only-matching $'\x1b\\]8;[^;]*;([^\x1b]+)\x1b\\\\.*?\x1b\\]8;;\x1b\\\\' --replace '$1'
}

filter() {
  text="$(cat)"
  filter_bare <<<"$text"
  filter_osc8 <<<"$text"
}

readarray -t urls < <(capture | filter | sort -u)

echo "${urls[*]}" >&2

if [[ -v urls ]]
then
  tmux display-popup -E -T 'Open url' "$(which tmux-urlview-popup) ${urls[*]}"
else
  tmux display-message "No urls found"
fi
