{ config, pkgs, lib, ... }: {
  # Needed for tray icons
  xdg.systemDirs.data = [ "${pkgs.sunshine}/share" ];

  systemd.user.services = {
    sunshine = {
      Unit = {
        After = "graphical-session.target";
        PartOf = "graphical-session.target";
      };
      Service = {
        ExecStart = lib.getExe' pkgs.sunshine "sunshine";
        Restart = "on-failure";
        RestartSteps = 5;
        RestartMaxDelaySec = 10;
      };
      Install.WantedBy = [ "graphical-session.target" ];
    };
  };

  xdg.configFile."sunshine/apps.json".text = ''
    {
      "env": {
        "PATH": "$(PATH)"
      },
      "apps": [
        {
          "name": "Desktop",
          "image-path": "desktop.png"
        }
      ]
    }
  '';
}
