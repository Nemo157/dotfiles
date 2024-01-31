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
    runtimeInputs = [ pkgs.mpc-cli pkgs.coreutils ];
    source = ./rand-album;
  };

  scripts.rofi-mpd = {
    runtimeInputs = [ pkgs.rofi pkgs.mpc-cli pkgs.beets pkgs.coreutils ];
    source = ./rofi-mpd;
  };

  services.playerctld.enable = true;
}
