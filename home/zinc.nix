{ lib, config, pkgs, ts, ... }: {
  imports = [
    ./cli
    ./cli/nixos.nix
    ./dev
    ./dev/nixos.nix
    ./chill
    ./desktop
    ./desktop/nixos.nix
    ./xdg.nix
    ./age.nix
    ./wluma.nix
    ./personal
    ./personal/nixos.nix
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
