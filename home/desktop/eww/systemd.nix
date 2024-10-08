{ lib, config, pkgs, ... }: {
  systemd.user.services = {
    eww-daemon = {
      Unit = {
        After = "graphical-session.target";
        PartOf = "graphical-session.target";
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
          "${pkgs.appearance-watcher}/bin"
        ];
        ExecStart = "eww daemon --no-daemonize";
        ExecReload = "eww reload";
        Restart = "on-failure";
        RestartSteps = 5;
        RestartMaxDelaySec = 10;
      };
      Install = {
        WantedBy = [ "graphical-session.target" ];
      };
    };

    eww-auto-open-taskbars = {
      Unit = {
        After = "graphical-session.target";
        PartOf = "graphical-session.target";
        BindsTo = "eww-daemon.service";
      };
      Service = {
        ExecStart = "${config.binHome}/eww-auto-open-taskbars";
        Restart = "on-failure";
        RestartSteps = 5;
        RestartMaxDelaySec = 10;
      };
      Install = {
        WantedBy = [ "graphical-session.target" ];
      };
    };
  };
}
