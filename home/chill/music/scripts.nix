{ lib, config, pkgs, ... }: {
  scripts.rand-album = {
    runtimeInputs = [ pkgs.mpc-cli ];
    text = ''
      mpc clear >/dev/null
      artist="$(mpc ls | shuf -n1)"
      album="$(mpc ls "$artist" | shuf -n1)"
      mpc add "$album"
      mpc play
    '';
  };

  scripts.music-status = {
    runtimeInputs = [ pkgs.mpc-cli pkgs.jq pkgs.playerctl ];
    text = ''
      {
        playerctl -p mpd metadata mpris:artUrl | jq -R '{ albumart: sub("file://"; "") }' || true

        mpc current -f '%artist%\f%album%\f%title%' | jq -R '
          . / "\f" | {
            current: {
              artist: .[0],
              album: .[1],
              title: .[2],
            }
          }
        ' || true

        mpc status '%currenttime%\f%totaltime%' | jq -R '
          def lpad: tostring | ("0" * (2 - length)) + .;
          def parse_time: . / ":" | (60 * (.[0] | tonumber) + (.[1] | tonumber));
          def format_time: "\(. / 60 | floor):\(. % 60 | lpad)";
          . / "\f"
            | (.[0] | parse_time) as $current
            | (.[1] | parse_time) as $total
            | {
              time: {
                current: $current | format_time,
                total: $total | format_time,
                remaining: ($total - $current) | format_time,
                percent: ($current / if $total > 0 then $total else 1 end * 100),
              },
            }
        ' || true

        mpc status '%state%\f%songpos%\f%length%' | jq -R '
          . / "\f"
            | (.[1] | tonumber) as $position
            | (.[2] | tonumber) as $length
            | {
              queue: {
                state: (if $position == 0 then "stopped" else .[0] end),
                position: $position,
                length: $length,
              }
            }
        ' || true
      } | jq -s 'map(to_entries) | flatten | from_entries'
    '';
  };

}
