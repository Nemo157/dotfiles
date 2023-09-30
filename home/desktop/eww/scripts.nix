{ lib, config, pkgs, pkgs-unstable, ... }: {
  scripts.eww-hypr-workspaces = {
    runtimeInputs = [ pkgs.hyprland pkgs.socat pkgs.jq pkgs.coreutils ];
    text = ''
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
                      | select(.address)
                      | {
                        class,
                        title,
                        active: (.address == env.AWI),
                      }
                    ]
                  }
                | . + {
                    active: (.id | tostring == env.AWS),
                  }
              ]
            '
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
      # I have no idea why this can't just be
      #   playerctl -p mpd metadata -f "$format" -F | jq -RMc "$script"
      # but for some reason that never updates when running under eww
      # (it works fine when running the script from the shell directly)
      playerctl -p mpd metadata -f "$format" -F | while read -r; do
        playerctl -p mpd metadata -f "$format" | jq -RMc "$script"
      done
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
      playerctl -p mpd metadata -f "$format" -F | while read -r; do
        playerctl -p mpd metadata -f "$format" | jq -RMc "$script"
      done
    '';
  };
}
