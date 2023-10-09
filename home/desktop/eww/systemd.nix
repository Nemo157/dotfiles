{ lib, config, pkgs, pkgs-unstable, ... }: {
  systemd.user.targets = {
    tray = {
      Unit = {
        After = "graphical-session-pre.target";
        BindsTo = "graphical-session-pre.target";
      };
      Install = {
        WantedBy = [ "hyprland-session.target" ];
      };
    };
  };

  systemd.user.services = {
    eww-daemon = {
      Unit = {
        After = "graphical-session-pre.target";
        BindsTo = "graphical-session-pre.target";
      };
      Service = {
        ExecSearchPath = [
          "${pkgs.eww-wayland}/bin"
          # eww tries to invoke things via sh
          "${pkgs.bash}/bin"
          # scripts and tools used in event handlers
          "${pkgs.playerctl}/bin"
          "${pkgs.hyprland}/bin"
          "${pkgs.jq}/bin"
          "${pkgs.gnused}/bin"
          config.binHome
        ];
        ExecStart = "eww daemon --no-daemonize";
        ExecReload = "eww reload";
      };
    };

    eww-taskbar = {
      Unit = {
        After = "eww-daemon.service";
        BindsTo = "eww-daemon.service";
      };
      Service = {
        Type = "oneshot";
        ExecSearchPath = "${pkgs.eww-wayland}/bin";
        ExecStartPre = "eww ping";
        ExecStart = "eww open taskbar";
        RemainAfterExit = true;
      };
      Install = {
        RequiredBy = [ "tray.target" ];
      };
    };
  };
}
