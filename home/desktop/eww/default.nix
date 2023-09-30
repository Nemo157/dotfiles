{ lib, config, pkgs, pkgs-unstable, ... }: {
  imports = [
    ./config.nix
    ./overlay.nix
    ./scripts.nix
    ./systemd.nix
  ];

  # can't use programs.eww because of how it symlinks the config dir breaking
  # eww's daemon socket detection

  home.packages = [ pkgs.eww-wayland ];
}
