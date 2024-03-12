{ lib, pkgs, ... }: {
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
      After = "graphical-session.target";
    };
    Service = {
      Environment = "RUST_LOG=debug";
      ExecStart = lib.getExe pkgs.wluma;
    };
    Install = {
      WantedBy = [ "graphical-session.target" ];
    };
  };
}
