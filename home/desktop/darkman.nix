{ lib, pkgs, ... }: {
  home.packages = [
    pkgs.darkman
  ];

  xdg.configFile."darkman/config.yaml".text = ''
    lat: 53.0
    lng: 13.5
    usegeoclue: false
    dbusserver: true
    portal: true
  '';

  systemd.user = {
    timers = {
      # 2100 is a bit late to be in dark mode even if sunset hasn't arrived yet
      darkman-force-early-darkmode = {
        Timer.OnCalendar = "20:00";
        Install.WantedBy = [ "graphical-session.target" ];
      };
    };
    services = {
      darkman-force-early-darkmode = {
        Unit.Requisite = "darkman.service";
        Service = {
          Type = "oneshot";
          ExecStart = "${lib.getExe pkgs.darkman} set dark";
        };
      };
    };
  };

  xdg.configFile."systemd/user/default.target.wants/darkman.service" = {
    source = "${pkgs.darkman}/share/systemd/user/darkman.service";
  };
}
