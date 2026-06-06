{ config, lib, pkgs, ... }:
let
  set-wallpaper = pkgs.writeShellApplication {
    name = "set-wallpaper";
    runtimeInputs = with pkgs; [ coreutils awww niri jq imagemagick ];
    text = lib.readFile ./set-wallpaper.sh;
  };

  change-wallpapers = pkgs.writeShellApplication {
    name = "change-wallpapers";
    runtimeInputs = with pkgs; [
      appearance-watcher
      coreutils
      fd
      niri
      imagemagick
      jq
      set-wallpaper
    ];
    text = lib.readFile ./change-wallpapers.sh;
  };
in {
  home.packages = [
    set-wallpaper
  ];

  systemd.user = {
    timers = {
      change-wallpaper = {
        Unit = {
          After = "graphical-session.target";
          PartOf = "graphical-session.target";
        };
        Timer = {
          OnStartupSec = 0;
          OnCalendar = "*:00";
        };
        Install.WantedBy = [ "graphical-session.target" ];
      };
    };

    services = {
      change-wallpaper = {
        Unit = {
          After = [ "awww-daemon.service" "xdg-desktop-portal.service" ];
          Requires = [ "awww-daemon.service" "xdg-desktop-portal.service" ];
        };
        Service = {
          Type = "oneshot";
          ExecStart = lib.getExe change-wallpapers;
          Nice = 5;
        };
      };

      change-wallpaper-ac = {
        Unit.PartOf = "ac.target";
        Service = {
          Type = "oneshot";
          RemainAfterExit = true;
          ExecStart = lib.getExe (pkgs.writeShellApplication {
            name = "sww-change-wallpapers-ac-on";
            runtimeInputs = with pkgs; [ coreutils systemd ];
            text = ''
              mkdir -p "$XDG_RUNTIME_DIR"/systemd/user/change-wallpaper.{timer,service}.d
              echo $'[Timer]\nOnCalendar=*:00/10' >"$XDG_RUNTIME_DIR"/systemd/user/change-wallpaper.timer.d/ac-override.conf
              systemctl --user daemon-reload
            '';
          });
          ExecStop = lib.getExe (pkgs.writeShellApplication {
            name = "sww-change-wallpapers-ac-off";
            runtimeInputs = with pkgs; [ coreutils systemd ];
            text = ''
              rm "$XDG_RUNTIME_DIR"/systemd/user/change-wallpaper.timer.d/ac-override.conf
              rm "$XDG_RUNTIME_DIR"/systemd/user/change-wallpaper.service.d/ac-override.conf
              systemctl --user daemon-reload
            '';
          });
        };
        Install.WantedBy = [ "ac.target" ];
      };

      awww-daemon = {
        Unit = {
          After = "graphical-session.target";
          PartOf = "graphical-session.target";
          Wants = "change-wallpaper.service";
        };
        Service = {
          ExecStart = "${lib.getExe' pkgs.awww "awww-daemon"} --no-cache";
          Restart = "on-failure";
          RestartSteps = 5;
          RestartMaxDelaySec = 10;
        };
        Install.WantedBy = [ "graphical-session.target" ];
      };
    };
  };

  xdg.dataFile = let
    trigger-change-wallpaper = pkgs.writeShellApplication {
      name = "trigger-change-wallpapers";
      runtimeInputs = with pkgs; [ systemd ];
      text = ''
        systemctl --user start --no-block change-wallpaper
      '';
    };
  in {
    "light-mode.d/trigger-change-wallpapers".source = lib.getExe trigger-change-wallpaper;
    "dark-mode.d/trigger-change-wallpapers".source = lib.getExe trigger-change-wallpaper;
  };
}
