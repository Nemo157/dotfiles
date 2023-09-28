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
}
