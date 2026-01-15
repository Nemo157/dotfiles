{ lib, config, pkgs, ts, hostname, ... }: {
  imports = [
    ./age.nix
    ./audio.nix
    ./chill
    ./chill-server
    ./cli
    ./common.nix
    ./desktop
    ./dev
    ./personal
    ./xdg.nix
  ];

  home.stateVersion = "23.05";

  programs.home-manager.enable = true;

  systemd.user.startServices = "sd-switch";

  home.packages = with pkgs; [
    stc-cli
    flatpak
    amdgpu_top
  ];

  services.syncthing = {
    enable = true;
    tray.enable = true;
    guiAddress = "${ts.ips.mithril}:8384";
  };


}
