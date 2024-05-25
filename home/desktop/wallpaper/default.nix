{ config, lib, pkgs, ... }:
let
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
          After = "swww-daemon.service";
          BindsTo = "swww-daemon.service";
        };
        Timer = {
          OnStartupSec = 0;
          OnUnitActiveSec = 3600;
        };
        Install.WantedBy = [ "graphical-session.target" ];
      };
    };

    services = {
      swww-change-wallpaper = {
        Service = {
          Type = "oneshot";
          ExecStart = lib.getExe change-wallpapers;
          Nice = 5;
          Environment = "WALLPAPER_DUMB=1";
        };
      };

      swww-change-wallpaper-ac = {
        Unit.PartOf = "ac.target";
        Service = {
          Type = "oneshot";
          RemainAfterExit = true;
          ExecStart = lib.getExe (pkgs.writeShellApplication {
            name = "sww-change-wallpapers-ac-on";
            runtimeInputs = with pkgs; [ coreutils systemd ];
            text = ''
              mkdir -p "$XDG_RUNTIME_DIR"/systemd/user/swww-change-wallpaper.{timer,service}.d
              echo $'[Timer]\nOnUnitActiveSec=600' >"$XDG_RUNTIME_DIR"/systemd/user/swww-change-wallpaper.timer.d/ac-override.conf
              echo $'[Service]\nEnvironment=WALLPAPER_DUMB=0' >"$XDG_RUNTIME_DIR"/systemd/user/swww-change-wallpaper.service.d/ac-override.conf
              systemctl --user daemon-reload
            '';
          });
          ExecStop = lib.getExe (pkgs.writeShellApplication {
            name = "sww-change-wallpapers-ac-off";
            runtimeInputs = with pkgs; [ coreutils systemd ];
            text = ''
              rm "$XDG_RUNTIME_DIR"/systemd/user/swww-change-wallpaper.timer.d/ac-override.conf
              rm "$XDG_RUNTIME_DIR"/systemd/user/swww-change-wallpaper.service.d/ac-override.conf
              systemctl --user daemon-reload
            '';
          });
        };
        Install.WantedBy = [ "ac.target" ];
      };

      swww-daemon = {
        Unit = {
          After = "graphical-session.target";
          BindsTo = "graphical-session.target";
        };
        Service = {
          ExecStart = "${lib.getExe' pkgs.swww "swww-daemon"} --no-cache";
          Restart = "on-failure";
        };
        Install.WantedBy = [ "graphical-session.target" ];
      };
    };
  };

  xdg.dataFile = let
    trigger-swww-change-wallpapers = pkgs.writeShellApplication {
      name = "trigger-swww-change-wallpapers";
      runtimeInputs = with pkgs; [ systemd ];
      text = ''
        systemctl --user start --no-block swww-change-wallpaper.service
      '';
    };
  in {
    "light-mode.d/trigger-swww-change-wallpapers".source = lib.getExe trigger-swww-change-wallpapers;
    "dark-mode.d/trigger-swww-change-wallpapers".source = lib.getExe trigger-swww-change-wallpapers;
  };
}
