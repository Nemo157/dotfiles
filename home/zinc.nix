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

  systemd.user = {
    services = {
      swww-change-wallpaper = {
        # Don't apply rescaling or blur, too expensive on battery
        Service.Environment = "WALLPAPER_DUMB=1";
      };
    };

    timers = {
      swww-change-wallpaper = {
        # Change wallpaper less often
        Timer.OnUnitActiveSec = lib.mkOverride 0 3000;
      };
    };
  };
}
