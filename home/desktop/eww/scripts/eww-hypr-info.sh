shopt -s nullglob

if [[ -v HYPRLAND_INSTANCE_SIGNATURE ]]
then
  get-info() {
    echo | jq \
        --argjson activewindow "$(hyprctl activewindow -j)" \
        --argjson activeworkspace "$(hyprctl activeworkspace -j)" \
        --argjson clients "$(hyprctl clients -j)" \
        --argjson monitors "$(hyprctl monitors -j)" \
        --argjson workspaces "$(hyprctl workspaces -j)" \
        --argjson names '["einz", "zwei", "drei", "vier", "funf"]' \
        -sMc '
      (
        [
          $names
          | keys.[]
          | {
              key: (. + 1) | tostring,
              value: {
                id: (. + 1),
                name: $names[.],
                active: false,
                virtual: true,
                windows: [],
              },
            }
        ]
        | from_entries
      ) as $virtual_workspaces
      | (
          $workspaces
          | sort_by(.id)
          | map(
              . as $workspace
              | {
                  key: .id | tostring,
                  value: ($workspace + {
                    name: (if .name == (.id | tostring) then $names[.id - 1] else .name end),
                    monitor: $monitors.[] | select(.id == $workspace.monitorID) | .model | (if . == "" then "Unknown" else . end),
                    virtual: false,
                    windows: [
                      $clients.[]
                      | select(.workspace.id == $workspace.id)
                      | select(.address and (.class | length > 0))
                      | {
                        class,
                        title,
                        address,
                        active: (.address == $activewindow.address),
                      }
                      | select(if .class == "steam" then .title != "" else true end)
                    ],
                    active: (.id == $activeworkspace.id),
                  })
                }
          ) | from_entries
        ) as $real_workspaces
        | [($virtual_workspaces + $real_workspaces).[]] as $workspaces
      | {
        activewindow: $activewindow,
        activeworkspace: $activeworkspace,
        workspaces: $workspaces,
      }
    ' | add_icons
  }

  wait-for-update() {
    SOCKET="UNIX-CONNECT:$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock"
    socat -u "$SOCKET",forever - | while read -r
    do
      info
      # Some events like closing windows fire before everything is updated,
      # check again after a little while :ferrisPensive:
      sleep 0.1
      info
    done
  }
fi

if [[ -v NIRI_SOCKET ]]
then
  get-info() {
    echo | jq \
        --argjson windows "$(niri msg -j windows)" \
        --argjson workspaces "$(niri msg -j workspaces)" \
        --argjson outputs "$(niri msg -j outputs)" \
        --argjson names '["einz", "zwei", "drei", "vier", "funf"]' \
        -sMc '
      (
        [
          $names
          | keys.[]
          | {
              key: (. + 1) | tostring,
              value: {
                idx: (. + 1),
                name: $names[.],
                active: false,
                virtual: true,
                windows: [],
              },
            }
        ]
        | from_entries
      ) as $virtual_workspaces
      | (
          $workspaces
          | sort_by(.idx)
          | map(
              . as $workspace
              | {
                  key: .idx | tostring,
                  value: ($workspace + {
                    name: (if .name then .name else $names[.idx - 1] end),
                    monitor: $outputs[.output].model,
                    virtual: false,
                    windows: [
                      $windows
                      | sort_by(.layout.pos_in_scrolling_layout)
                      | .[]
                      | select(.workspace_id == $workspace.id)
                      | select(.app_id | length > 0)
                      | {
                        class: .app_id,
                        title,
                        active: .is_focused,
                      }
                      | select(if .class == "steam" then .title != "" else true end)
                    ],
                    active: .is_active,
                  })
                }
          ) | from_entries
        ) as $real_workspaces
        | [($virtual_workspaces + $real_workspaces).[]] as $workspaces
      | {
        workspaces: $workspaces,
      }
    ' | add_icons
  }

  wait-for-update() {
    niri msg -j event-stream | jq -r --unbuffered 'keys.[] | select(contains("Window") or contains("Workspace"))' | while read -r _
    do
      info
    done
  }
fi

add_icons() {
  IFS=$':\n' read -r -a xdg_data_dirs <<<"${XDG_DATA_DIRS?:}"

  while read -r line
  do
    workspaces=$(jq -Mc '.workspaces[]' <<<"$line" | while read -r workspace
    do
      windows=$(jq -Mc '.windows[]' <<<"$workspace" | while read -r window
      do
        class="$(jq -rM '.class' <<<"$window")"
        for dir in "${xdg_data_dirs[@]}"
        do
          for icon in "$dir"/{icons/hicolor/{scalable,64x64,128x128,256x256,48x48,32x32,16x16,512x512}/apps,pixmaps}/*{"$class","${class@L}","${class@u}"}.{svg,png}
          do
            if [ -f "$icon" ]
            then
              window="$(icon="$icon" jq -Mc '. + { icon: env.icon }' <<<"$window")"
              break 2
            fi
          done
        done
        cat <<<"$window"
      done | jq -sMc '{ windows: . }')
      (cat <<<"$workspace"; cat <<<"$windows") | jq -sMc 'map(to_entries) | flatten | from_entries'
    done | jq -sMc '{ workspaces: . }')
    (cat <<<"$line"; cat <<<"$workspaces") | jq -sMc 'map(to_entries) | flatten | from_entries'
  done
}

prev=
info() {
  if new="$(get-info)" && [ "$prev" != "$new" ]
  then
    prev="$new"
    echo "$new"
  fi
}

info

wait-for-update
