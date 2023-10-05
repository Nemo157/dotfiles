{ lib, config, pkgs, pkgs-unstable, ... }: {
  imports = [
    ./config.nix
    ./scripts
    ./systemd.nix
  ];

  # can't use programs.eww because of how it symlinks the config dir breaking
  # eww's daemon socket detection

  home.packages = [ pkgs.eww-wayland ];
}
