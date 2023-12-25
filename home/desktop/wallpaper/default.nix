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
        Install.WantedBy = [ "graphical-session.target" ];
      };
    };

    services = {
      swww-change-wallpaper = {
        Service = {
          Type = "oneshot";
          ExecStart = lib.getExe change-wallpapers;
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
}
