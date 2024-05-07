capture() {
  start="$(tmux display-message -p '#{?#{==:#{pane_mode},copy-mode},-#{scroll_position},0}')"
  end="$(tmux display-message -p '#{?#{==:#{pane_mode},copy-mode},#{e|-:#{pane_height},#{scroll_position}},#{pane_height}}')"
  tmux capture-pane -Jpe -S "$start" -E "$end"
}

filter() {
  rg --only-matching 'https?://[-a-zA-Z0-9@:%._\+~#=]{1,256}\.[a-zA-Z0-9()]{2,6}\b([-a-zA-Z0-9()@:%_\+.~#?&//=]*)'
}

readarray -t urls < <(capture | filter | sort -u)

if [[ -v urls ]]
then
  tmux display-popup -E -T 'Open url' "$(which tmux-urlview-popup) ${urls[*]}"
else
  tmux display-message "No urls found"
fi
