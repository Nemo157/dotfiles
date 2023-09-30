{ lib, config, pkgs, ... }: {
  scripts.rand-album = {
    runtimeInputs = [ pkgs.mpc-cli pkgs.coreutils ];
    text = ''
      mpc clear >/dev/null
      artist="$(mpc ls | shuf -n1)"
      album="$(mpc ls "$artist" | shuf -n1)"
      mpc add "$album"
      mpc play
    '';
  };
}
