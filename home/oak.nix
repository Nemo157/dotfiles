{ lib, config, pkgs, ... }: {
  imports = [
    ./cli
    ./dev
    ./desktop
    ./xdg.nix
    ./age.nix
    ./wluma.nix
    ./veecle
  ];

  home.stateVersion = "24.05";

  programs.home-manager.enable = true;

  home.packages = with pkgs; [ wluma ];
}
