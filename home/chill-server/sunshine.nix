{ config, pkgs, lib, ... }: {
  # Needed for tray icons
  xdg.systemDirs.data = [ "${pkgs.sunshine}/share" ];

  systemd.user.services = {
    sunshine = {
      Unit.Description = pkgs.sunshine.meta.description;
      Service = {
        ExecStart = lib.getExe' pkgs.sunshine "sunshine";
        Restart = "on-abnormal";
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
