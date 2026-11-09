#!/usr/bin/env bash
set -euo pipefail

pane_tty="$(tmux display-message -p '#{pane_tty}')"
if [[ -z "$pane_tty" ]]; then
  echo "not running inside a tmux pane" >&2
  exit 1
fi

# Find the foreground process of the pane: ps marks processes in the foreground
# process group of a tty with '+' in the STAT column. The top-level process is
# the group leader, identified exactly by pid == pgid rather than by ps's pid
# ordering — a PID-number wrap can give a subprocess a lower pid than its own
# parent script, so the lowest-pid foreground member is not necessarily the
# leader. Falls back to the lowest-pid survivor when the leader is dead
# (an orphaned group left behind by a script that spawned a long-lived child).
pid=""
argv0=""
while read -r p pgid stat argv0 _; do
  if [[ "$stat" == *'+'* ]]; then
    if [[ "$p" == "$pgid" ]]; then
      pid="$p"
      break
    elif [[ -z "$pid" ]]; then
      pid="$p"
    fi
  fi
done < <(ps -t "$pane_tty" --sort=pid -o pid=,pgid=,stat=,args=)

if [[ -z "$pid" ]]; then
  tmux display-message "no foreground process in pane"
  exit 1
fi

kill -USR1 "$pid"
tmux display-message "sent SIGUSR1 to $pid ($argv0)"
