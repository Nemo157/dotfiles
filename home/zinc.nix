{ lib, config, pkgs, ... }: {
  imports = [
    ./cli
    ./desktop
  ];

  home.stateVersion = "23.05";

  programs.home-manager.enable = true;

  home.packages = [
    pkgs.flatpak
  ];

  xdg.userDirs = {
    enable = true;
    music = "${config.home.homeDirectory}/Music/Library";
  };
  xdg.systemDirs.data = [
    "${config.xdg.dataHome}/flatpak/exports/share"
  ];

  wayland.windowManager.hyprland.modifier = "SUPER";
}
