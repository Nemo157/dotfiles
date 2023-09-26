{ lib, config, pkgs, ... }: {
  home.file.".local/bin/rand-album".source = pkgs.writeShellScript "rand-album" (
    let
      mpc = lib.getExe pkgs.mpc-cli;
      beet = "${config.programs.beets.package}/bin/beet";
    in ''
      ${mpc} clear >/dev/null
      sh -c "$(${beet} random -a -f '${mpc} findadd album "$album"')"
      ${mpc} play
    '');
}
