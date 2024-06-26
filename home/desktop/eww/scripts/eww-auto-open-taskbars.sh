open-taskbars() {
  local model
  hyprctl monitors -j | jq -r '.[].model | if . == "" then "Unknown" else . end' | while read -r model
  do
    # I hope there's never more than one unknown model
    echo "opening taskbar for '$model'" >&2
    eww open taskbar --id "$model" --screen "$model"
  done
}

open-taskbars

SOCKET="$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock"
socat -u "UNIX-CONNECT:$SOCKET,forever" - | while read -r event
do
  if [ "${event%>>*}" == "monitoradded" ]
  then
    echo "monitor added event detected" >&2
    eww close-all
    open-taskbars
    systemctl --user start --no-block swww-change-wallpaper
  fi
done
