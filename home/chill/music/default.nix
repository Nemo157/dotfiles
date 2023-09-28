{ lib, config, pkgs, ... }: {
  imports = [
    ./ncmpcpp.nix
    ./beets.nix
    ./mpd.nix
    ./scripts.nix
  ];

  services.playerctld.enable = true;
}
