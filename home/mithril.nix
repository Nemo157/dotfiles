{ lib, config, pkgs, ... }: {
  imports = [
    ./cli
    ./desktop
    ./chill
  ];

  home.stateVersion = "23.05";

  programs.home-manager.enable = true;

  services.syncthing= {
    enable = true;
    tray.enable = true;
  };
}
