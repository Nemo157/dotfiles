{ config, lib, pkgs, ... }:
let
  swww = pkgs.swww;
  set-wallpaper = pkgs.writeShellApplication {
    name = "set-wallpaper";
    runtimeInputs = with pkgs; [ coreutils swww hyprland jq imagemagick ];
    text = lib.readFile ./set-wallpaper.sh;
  };
  change-wallpapers = pkgs.writeShellApplication {
    name = "change-wallpapers";
    runtimeInputs = with pkgs; [ coreutils fd hyprland jq set-wallpaper systemd imagemagick ];
    text = lib.readFile ./change-wallpapers.sh;
  };
  trigger-swww-change-wallpapers = pkgs.writeShellScript "trigger-swww-change-wallpapers.sh" ''
    ${pkgs.systemd}/bin/systemctl --user start --no-block swww-change-wallpaper.service
  '';
in {
  systemd.user = {
    timers = {
      swww-change-wallpaper = {
        Unit = {
          After = "swww.service";
          BindsTo = "swww.service";
        };
        Timer = {
          OnActiveSec = 0;
          OnUnitActiveSec = 600;
        };
        Install.WantedBy = [ "graphical-session.target" "swww.service" ];
      };
    };

    services = {
      swww-change-wallpaper = {
        Service = {
          Type = "oneshot";
          ExecStart = lib.getExe change-wallpapers;
          Nice = 5;
        };
      };

      swww = {
        Service = {
          ExecStart = lib.getExe' swww "swww-daemon";
          Restart = "on-failure";
        };
        Install.WantedBy = [ "graphical-session.target" ];
      };
    };
  };

  xdg.dataFile = {
    "light-mode.d/trigger-swww-change-wallpapers".source = trigger-swww-change-wallpapers;
    "dark-mode.d/trigger-swww-change-wallpapers".source = trigger-swww-change-wallpapers;
  };
}
