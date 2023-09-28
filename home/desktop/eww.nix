{ lib, config, pkgs-unstable, ... }: {
  programs.eww = {
    enable = true;
    package = pkgs-unstable.eww-wayland;
    configDir = ./eww;
  };
}
