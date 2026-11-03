#!/usr/bin/env bash
set -euo pipefail

pane_tty="$(tmux display-message -p '#{pane_tty}')"
if [[ -z "$pane_tty" ]]; then
  echo "not running inside a tmux pane" >&2
  exit 1
fi

# Find the foreground process of the pane: ps marks processes in the foreground
# process group of a tty with '+' in the STAT column. Taking the first one
# reaches the process group leader, the process that is actively attached to
# the pane (or the shell itself when nothing is running).
pid=""
argv0=""
while read -r p stat argv0 _; do
  if [[ "$stat" == *'+'* ]]; then
    pid="$p"
    break
  fi
done < <(ps -t "$pane_tty" -o pid=,stat=,args=)

if [[ -z "$pid" ]]; then
  tmux display-message "no foreground process in pane"
  exit 1
fi

kill -USR1 "$pid"
tmux display-message "sent SIGUSR1 to $pid ($argv0)"
