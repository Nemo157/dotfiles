open-taskbars() {
  local model
  hyprctl monitors -j | jq -r '.[].model | if . == "" then "Unknown" else . end' | while read -r model
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

while true
do
  SOCKET="$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock"
  socat -u "UNIX-CONNECT:$SOCKET,forever" - | while read -r event
  do
    if [ "${event%>>*}" == "monitoradded" ]
    then
      echo "monitor added event detected" >&2
      open-taskbars
    fi
  done
done
