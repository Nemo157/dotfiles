{ lib, config, pkgs, ... }: {
  imports = [
    ./cli
    ./chill
    ./desktop
    ./xdg.nix
    ./age.nix
    ./wluma.nix
  ];

  home.stateVersion = "23.05";

  programs.home-manager.enable = true;

  home.packages = with pkgs; [
    flatpak
    wluma
  ];

  services.syncthing = {
    enable = true;
    tray.enable = true;
  };

}
