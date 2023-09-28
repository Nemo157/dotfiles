{ lib, config, pkgs, ... }: {
  scripts.rand-album = {
    runtimeInputs = [ pkgs.mpc-cli config.programs.beets.package ];
    text = ''
      mpc clear >/dev/null
      # shellcheck disable=SC2016
      sh -c "$(beet random -a -f 'mpc findadd album "$album"')"
      mpc play
    '';
  };

  scripts.music-status = {
    runtimeInputs = [ pkgs.mpc-cli pkgs.jq pkgs.playerctl ];
    text = ''
      if [ "$(mpc status '%state%')" == playing ]
      then
        playerctl -p mpd metadata artist | jq -R '{ artist: . }'
        playerctl -p mpd metadata album | jq -R '{ album: . }'
        playerctl -p mpd metadata mpris:artUrl | jq -R '{ albumart: sub("file://"; "") }'
        playerctl -p mpd metadata title | jq -R '{ title: . }'
        mpc status '%currenttime%\f%totaltime%\f%percenttime%\f%songpos%\f%length%' | jq -R '
          def lpad: tostring | ("0" * (2 - length)) + .;
          def parse_time: . / ":" | (60 * (.[0] | tonumber) + (.[1] | tonumber));
          def format_time: "\(. / 60 | floor):\(. % 60 | lpad)";
          . / "\f" | {
            time: {
              current: .[0],
              total: .[1],
              remaining: ((.[1] | parse_time) - (.[0] | parse_time)) | format_time,
              percent: (.[2] | gsub("[ %]"; "") | tonumber),
            },
            queue: {
              position: .[3],
              length: .[4],
            }
          }
        '
      fi | jq -s 'map(to_entries) | flatten | from_entries'
    '';
  };

}
