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

  services.playerctld.enable = true;
}
