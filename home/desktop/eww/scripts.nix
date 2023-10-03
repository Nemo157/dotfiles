{ lib, config, pkgs, pkgs-unstable, ... }: {
  scripts.eww-hypr-workspaces = {
    runtimeInputs = [ pkgs.hyprland pkgs.socat pkgs.jq pkgs.coreutils ];
    text = ''
      shopt -s nullglob

      IFS=$':\n' read -r -a xdg_data_dirs <<<"''${XDG_DATA_DIRS?:}"
      dirs=("''${xdg_data_dirs[@]/%//icons}")

      add_icons() {
        while read -r line
        do
          jq -Mc '.[]' <<<"$line" | while read -r workspace
          do
            windows=$(jq -Mc '.windows[]' <<<"$workspace" | while read -r window
            do
              class="$(jq -rM '.class' <<<"$window")"
              for dir in "''${dirs[@]}"
              do
                for icon in "$dir"/hicolor/{scalable,64x64,128x128,256x256,48x48,32x32,16x16,512x512}/apps/*{"$class","''${class@L}","''${class@u}"}.{svg,png}
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
          done | jq -sMc '.'
        done
      }

      spaces() {
        AWS=$(hyprctl activeworkspace -j | jq '.id')
        AWI=$(hyprctl activewindow -j | jq -r '.address')
        export AWS AWI
        {
          echo '[
            {"workspace":{"id":1,"name":"einz"}},
            {"workspace":{"id":2,"name":"zwei"}},
            {"workspace":{"id":3,"name":"drei"}},
            {"workspace":{"id":4,"name":"vier"}}
          ]'
          hyprctl clients -j
        } | jq -sMc '
          [
            flatten
            | group_by(.workspace.id)
            | .[]
            | .[0].workspace + {
                windows: [
                  .[]
                  | select(.address and (.class | length > 0))
                  | {
                    class,
                    title,
                    address,
                    active: (.address == env.AWI),
                  }
                ]
              }
            | select((.windows | any) or (.name | length > 0))
            | . + {
                active: (.id | tostring == env.AWS),
              }
          ]
        ' | add_icons
      }

      spaces
      SOCKET="UNIX-CONNECT:/tmp/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock"
      socat -u "$SOCKET" - | while read -r; do
        spaces
        # Some events like closing windows fire before everything is updated,
        # check again after a little while :ferrisPensive:
        sleep 0.1
        spaces
      done
    '';
  };

  scripts.eww-color-scheme = {
    runtimeInputs = [ pkgs.jq pkgs.systemd ];
    text = ''
      export svc=org.freedesktop.portal.Desktop
      export obj=/org/freedesktop/portal/desktop
      export int=org.freedesktop.portal.Settings
      export ns=org.freedesktop.appearance
      export key=color-scheme

      toname() {
        while read -r value
        do
          case "$value" in
            0) echo light ;;
            1) echo dark ;;
            2) echo light ;;
            *)
              echo >&2 "unknown $key value $value"
              echo light
              ;;
          esac
        done
      }

      busctl -j --user call $svc $obj $int Read ss $ns $key  | jq -Mc '
        .data[0].data.data
      ' | toname

      busctl -j --user monitor $svc | jq --unbuffered -Mc '
        select(
          .type == "signal"
          and .path == env.obj
          and .interface == env.int
          and .member == "SettingChanged"
          and .payload.type == "ssv"
          and .payload.data[0] == env.ns
          and .payload.data[1] == env.key
        )
        | .payload.data[2].data
      ' | toname
    '';
  };

  scripts.eww-music-queue = {
    runtimeInputs = [ pkgs.mpc-cli pkgs.jq pkgs.playerctl ];
    text = ''
      playerctl -p mpd metadata -f '{{xesam:title}}}' -F | while read -r; do
        {
          mpc status '%songpos%\f%length%' | jq -R '
            . / "\f"
              | (.[0] | tonumber) as $position
              | (.[1] | tonumber) as $length
              | {
                position: $position,
                length: $length,
              }
          ' || true
        } | jq -sMc 'map(to_entries) | flatten | from_entries'
      done
    '';
  };

  scripts.eww-music-status = {
    runtimeInputs = [ pkgs.jq pkgs.playerctl ];
    text = ''
      format='{{status}}{{position}}'
      script='
        . / ""
        | {
            state: (.[0] | ascii_downcase),
            position: (.[1] | tonumber / 1000000),
          }
      '
      playerctl -p mpd metadata -f "$format" -F | jq --unbuffered -RMc "$script"
    '';
  };

  scripts.eww-music-metadata = {
    runtimeInputs = [ pkgs.jq pkgs.playerctl ];
    text = ''
      format='{{xesam:albumArtist}}{{xesam:album}}{{xesam:title}}{{mpris:length}}{{mpris:artUrl}}'
      script='
        def ornull: if length > 0 then . else null end;
        . / ""
        | {
            artist: .[0] | ornull,
            album: .[1] | ornull,
            title: .[2] | ornull,
            duration: (.[3] | if length > 0 then tonumber / 1000000 else 0 end),
            albumart: (.[4] | sub("file://"; "") | ornull),
          }
      '
      playerctl -p mpd metadata -f "$format" -F | jq --unbuffered -RMc "$script"
    '';
  };
}
