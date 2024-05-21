{ lib, pkgs, ... }: let
  systemctl = lib.getExe' pkgs.systemd "systemctl";
in {
  systemd.targets = {
    ac = {
      description = "On AC power";
      unitConfig = {
        DefaultDependencies = false;
      };
      wantedBy = [ "multi-user.target" ];
    };
  };

  systemd.services = {
    "ac@" = {
      description = "On AC power (notify %I)";
      partOf = [ "ac.target" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = "${systemctl} --user --machine=%i@ start --wait ac.target";
      };
    };
    "ac@nemo157" = {
      overrideStrategy = "asDropin";
      wantedBy = [ "ac.target" ];
    };
  };

  systemd.user.targets = {
    ac = {
      description = "On AC power";
      conflicts = [ "battery.target" ];
      unitConfig = {
        DefaultDependencies = false;
      };
    };
  };
}
