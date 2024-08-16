{ config, lib, pkgs, ... }:
let
  set-wallpaper = pkgs.writeShellApplication {
    name = "set-wallpaper";
    runtimeInputs = with pkgs; [ coreutils swww hyprland jq imagemagick ];
    text = lib.readFile ./set-wallpaper.sh;
  };

  change-wallpapers = pkgs.writeShellApplication {
    name = "change-wallpapers";
    runtimeInputs = with pkgs; [
      appearance-watcher
      coreutils
      fd
      hyprland
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
      swww-change-wallpaper = {
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
      swww-change-wallpaper = {
        Unit = {
          After = [ "swww-daemon.service" "xdg-desktop-portal.service" ];
          Requires = [ "swww-daemon.service" "xdg-desktop-portal.service" ];
        };
        Service = {
          Type = "oneshot";
          ExecStart = lib.getExe change-wallpapers;
          Nice = 5;
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
              echo $'[Timer]\nOnCalendar=*:00/10' >"$XDG_RUNTIME_DIR"/systemd/user/swww-change-wallpaper.timer.d/ac-override.conf
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
          PartOf = "graphical-session.target";
          Wants = "swww-change-wallpaper.service";
        };
        Service = {
          ExecStart = "${lib.getExe' pkgs.swww "swww-daemon"} --no-cache";
          Restart = "on-failure";
          RestartSteps = 5;
          RestartMaxDelaySec = 10;
        };
        Install.WantedBy = [ "graphical-session.target" ];
      };
    };
  };

  xdg.dataFile = let
    trigger-swww-change-wallpaper = pkgs.writeShellApplication {
      name = "trigger-swww-change-wallpapers";
      runtimeInputs = with pkgs; [ systemd ];
      text = ''
        systemctl --user start --no-block swww-change-wallpaper
      '';
    };
  in {
    "light-mode.d/trigger-swww-change-wallpapers".source = lib.getExe trigger-swww-change-wallpaper;
    "dark-mode.d/trigger-swww-change-wallpapers".source = lib.getExe trigger-swww-change-wallpaper;
  };
}
