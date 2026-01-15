get-monitors() {
  niri msg -j outputs | jq -r '.[] | select(.current_mode) | .model | if . == "" then "Unknown" else . end'
}

wait-for-monitor-change() {
  # There are no events for outputs, but if the outputs change the workspaces
  # must change since each output should have an active workspace.
  niri msg -j event-stream | jq -r --unbuffered 'keys.[] | select(. == "WorkspacesChanged")' | while read -r _
  do
    echo "workspace change detected, maybe monitor related" >&2
    open-taskbars
  done
}

open-taskbars() {
  local model
  get-monitors | while read -r model
  do
    # I hope there's never more than one unknown model
    if eww active-windows | rg "$model: taskbar" >/dev/null
    then
      echo "taskbar already open for '$model'" >&2
    else
      echo "opening taskbar for '$model'" >&2
      while ! eww open taskbar --id "$model" --screen "$model" >&2
      do
        echo "opening failed, retrying in 1 sec" >&2
        sleep 1
      done
      systemctl --user start --no-block swww-change-wallpaper
    fi
  done
}

while ! eww ping >/dev/null
do
  echo "eww not available, retrying in 1 sec" >&2
  sleep 1
done

open-taskbars
wait-for-monitor-change
