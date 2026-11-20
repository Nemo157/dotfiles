start="$(tmux display-message -p '#{?#{==:#{pane_mode},copy-mode},-#{scroll_position},0}')"
end="$(tmux display-message -p '#{e|-:#{pane_height},#{?#{==:#{pane_mode},copy-mode},#{e|+:#{scroll_position},1},1}}')"
width="$(tmux display-message -p '#{pane_width}')"
height="$(tmux display-message -p '#{pane_height}')"
# carry over any per-pane default colours, `default` keeps the popup-style
style="$(tmux display-message -p 'fg=#{pane_fg},bg=#{pane_bg}')"

file="$(mktemp -t tmux-urlview-overlay.XXXXXX)"
# -N keeps trailing cells so background colours extend to the line end
tmux capture-pane -peN -S "$start" -E "$end" >"$file"

if ! "$TMUX_URLVIEW_OVERLAY" check "$file" "$width"; then
  rm -f "$file"
  tmux display-message "No urls found"
  exit 0
fi

# borderless popup exactly covering the current pane
tmux display-popup -E -B -x P -y P -w "$width" -h "$height" -s "$style" \
  "$TMUX_URLVIEW_OVERLAY show '$file' '$width'"
