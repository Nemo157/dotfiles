{ lib, config, pkgs, ... }: {
  imports = [
    ./ncmpcpp.nix
    ./beets.nix
    ./mpd.nix
  ];

  home.packages = [
    pkgs.playerctl
  ];

  scripts.rand-album = {
    runtimeInputs = [ pkgs.mpc pkgs.coreutils ];
    source = ./rand-album.sh;
  };

  scripts.rofi-mpd = {
    runtimeInputs = [ pkgs.rofi pkgs.mpc pkgs.beets pkgs.coreutils ];
    source = ./rofi-mpd.sh;
  };

  services.playerctld.enable = true;
}
