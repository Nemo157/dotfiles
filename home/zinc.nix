{ lib, config, pkgs, ... }: {
  imports = [
    ./cli
    ./chill
    ./desktop
  ];

  home.stateVersion = "23.05";

  programs.home-manager.enable = true;

  home.packages = with pkgs; [
    flatpak
    wluma
  ];

  xdg.userDirs = {
    enable = true;
    music = "${config.home.homeDirectory}/Music/Library";
  };
  xdg.systemDirs.data = [
    "${config.xdg.dataHome}/flatpak/exports/share"
  ];

  services.syncthing = {
    enable = true;
    tray.enable = true;
  };

  xdg.configFile."wluma/config.toml".text = ''
    [als.iio]
    path = "/sys/bus/iio/devices"
    thresholds = { 0 = "night", 2 = "dark", 8 = "dim", 15 = "normal", 50 = "bright", 100 = "outdoors" }

    [[output.backlight]]
    name = "integrated-screen"
    path = "/sys/class/backlight/acpi_video0"
    capturer = "wlroots"

    [[keyboard]]
    name = "integrated-keyboard"
    path = "/sys/class/leds/apple::kbd_backlight"
  '';

  systemd.user.services.wluma = {
    Unit = {
      Description = pkgs.wluma.meta.description;
      After = "graphical-session-pre.target";
    };
    Service = {
      Environment = "RUST_LOG=debug";
      ExecStart = "${pkgs.wluma}/bin/wluma";
    };
    Install = {
      WantedBy = [ "hyprland.target" ];
    };
  };
}
