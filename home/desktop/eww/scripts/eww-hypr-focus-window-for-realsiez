# Derived from
# https://github.com/hyprwm/Hyprland/issues/1234#issuecomment-1353633403

address="$1"
echo "$address" >&2

clients="$(hyprctl clients -j)"

ws=$(echo "$clients" | jq -r --arg address "$address" '.[] | select(.address == $address) | .workspace.id')
readarray -t fs_client < <(echo "$clients" | jq -r --argjson WS "$ws" '.[] | select(.workspace.id == $WS) | select(.fullscreen == true) | (.address, .fullscreenMode)')

commands=()

if [ -n "${fs_client[*]}" ]; then
  commands+=("dispatch focuswindow address:${fs_client[0]}")
  commands+=("dispatch fullscreen ${fs_client[1]}")
fi

commands+=("dispatch focuswindow address:$address")

if [ -n "${fs_client[*]}" ]; then
  commands+=("dispatch fullscreen ${fs_client[1]}")
fi

hyprctl --batch "$(IFS=';' ; echo "${commands[*]}")"
