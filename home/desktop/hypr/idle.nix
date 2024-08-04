{ lib, pkgs, ... }:
let
  hyprctl = lib.getExe' pkgs.hyprland "hyprctl";
  hypridle = lib.getExe pkgs.hypridle;
  hyprlock = lib.getExe pkgs.hyprlock;

  pidof = lib.getExe' pkgs.procps "pidof";
  pkill = lib.getExe' pkgs.procps "pkill";
  rofi = lib.getExe pkgs.rofi;

  loginctl = lib.getExe' pkgs.systemd "loginctl";
  systemctl = lib.getExe' pkgs.systemd "systemctl";
in {
  home.packages = [pkgs.hypridle];

  xdg.configFile = {
    "hypr/hypridle.conf" = {
      text = ''
        general {
            lock_cmd = ${pidof} hyprlock || ${hyprlock}
            before_sleep_cmd = ${loginctl} lock-session
            after_sleep_cmd = ${hyprctl} dispatch dpms on
        }

        listener {
            timeout = 270
            on-timeout = ${rofi} -e 'locking in 30s' -theme-str 'textbox { horizontal-align: 0.5; }'
            on-resume = ${pkill} -e -s0 rofi
        }

        listener {
            timeout = 300
            on-timeout = ${loginctl} lock-session
        }

        listener {
            timeout = 330
            on-timeout = ${hyprctl} dispatch dpms off
            on-resume = ${hyprctl} dispatch dpms on
        }

        listener {
            timeout = 1800
            on-timeout = ${systemctl} suspend
        }
      '';
      onChange = "${systemctl} --user restart hypridle";
    };

    "systemd/user/graphical-session.target.wants/hypridle.service" = {
      source = "${pkgs.hypridle}/share/systemd/user/hypridle.service";
    };
  };
}
