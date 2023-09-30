{ lib, config, pkgs, ... }: {
  imports = [
    ./ncmpcpp.nix
    ./beets.nix
    ./mpd.nix
    ./scripts.nix
  ];

  home.packages = [
    pkgs.playerctl
  ];

  services.playerctld.enable = true;
}
