{ lib, config, pkgs, ts, ... }: {
  imports = [
    ./cli
    ./dev
    ./chill
    ./desktop
    ./xdg.nix
    ./age.nix
    ./wluma.nix
    ./personal
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
    guiAddress = "${ts.ips.zinc}:8384";
  };
}
