{ lib, config, pkgs, ts, hostname, ... }: {
  imports = [
    ./age.nix
    ./audio.nix
    ./chill
    ./chill-server
    ./cli
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

  scripts."switch-to-virtual-monitor" = {
    runtimeInputs = with pkgs; [ hyprland eww systemd ];
    text = ''
        hyprctl output create headless
        hyprctl keyword monitor HEADLESS-2,2560x1600@60,0x0,1
        hyprctl keyword monitor HDMI-A-1,1920x1080,0x0,1
        hyprctl keyword monitor HDMI-A-1,disable
        eww close-all
        eww open taskbar
    '';
  };
}
