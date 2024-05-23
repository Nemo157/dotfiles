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
    ${pkgs.systemd}/bin/systemctl --user start --no-block swww-change-wallpaper.target
  '';
in {
  systemd.user = {
    timers = {
      "swww-change-wallpaper@" = {
        Unit = {
          After = "swww.service";
          BindsTo = "swww.service";
        };
      };
    };

    services = {
      "swww-change-wallpaper@" = {
         Unit = {
          PartOf = "swww-change-wallpaper.target";
        };
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

    targets = {
      "swww-change-wallpaper" = {
        Unit = {
          DefaultDependencies = false;
        };
      };
    };
  };

  xdg.configFile = {
    "systemd/user/ac.target.wants/swww-change-wallpaper@ac.timer".source = config.lib.file.mkOutOfStoreSymlink "${config.xdg.configHome}systemd/user/swww-change-wallpaper@.timer";
    "systemd/user/battery.target.wants/swww-change-wallpaper@battery.timer".source = config.lib.file.mkOutOfStoreSymlink "${config.xdg.configHome}/systemd/user/swww-change-wallpaper@.timer";

    "systemd/user/swww-change-wallpaper.target.wants/swww-change-wallpaper@ac.service".source = config.lib.file.mkOutOfStoreSymlink "${config.xdg.configHome}systemd/user/swww-change-wallpaper@.service";
    "systemd/user/swww-change-wallpaper.target.wants/swww-change-wallpaper@battery.service".source = config.lib.file.mkOutOfStoreSymlink "${config.xdg.configHome}systemd/user/swww-change-wallpaper@.service";

    "systemd/user/swww-change-wallpaper@ac.timer.d/overrides.conf".text = ''
      [Unit]
      PartOf=ac.target
      Requisite=ac.target
      [Timer]
      OnActiveSec=0
      OnUnitActiveSec=600
    '';

    "systemd/user/swww-change-wallpaper@battery.timer.d/overrides.conf".text = ''
      [Unit]
      PartOf=battery.target
      Requisite=battery.target
      [Timer]
      OnActiveSec=3600
      OnUnitActiveSec=3600
    '';

    "systemd/user/swww-change-wallpaper@battery.service.d/overrides.conf".text = ''
      # Don't apply rescaling or blur, too expensive on battery
      [Service]
      Environment=WALLPAPER_DUMB=1
    '';
  };

  xdg.dataFile = {
    "light-mode.d/trigger-swww-change-wallpapers".source = trigger-swww-change-wallpapers;
    "dark-mode.d/trigger-swww-change-wallpapers".source = trigger-swww-change-wallpapers;
  };
}
