{ lib, config, pkgs, ... }: {
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
          "${pkgs.eww}/bin"
          # eww tries to invoke things via sh
          "${pkgs.bash}/bin"
          # scripts and tools used in event handlers
          "${pkgs.playerctl}/bin"
          "${pkgs.hyprland}/bin"
          "${pkgs.jq}/bin"
          "${pkgs.gnused}/bin"
          "${pkgs.coreutils}/bin"
          config.binHome
          "${pkgs.systemd}/bin"
        ];
        ExecStart = "eww daemon --no-daemonize";
        ExecReload = "eww reload";
      };
    };

    eww-auto-open-taskbars = {
      Unit = {
        After = "eww-daemon.service";
        BindsTo = "eww-daemon.service";
      };
      Service = {
        ExecStart = "${config.binHome}/eww-auto-open-taskbars";
      };
      Install = {
        RequiredBy = [ "tray.target" ];
      };
    };
  };
}
