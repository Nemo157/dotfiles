{ lib, pkgs, ... }: let
  systemctl = lib.getExe' pkgs.systemd "systemctl";
in {
  systemd.targets = {
    ac = {
      description = "On AC power";
      unitConfig = {
        DefaultDependencies = false;
        After = "multi-user.target";
      };
      wantedBy = [ "multi-user.target" ];
    };
  };

  systemd.user.targets = {
    ac = {
      description = "On AC power";
      unitConfig = {
        DefaultDependencies = false;
        After = "default.target";
      };
      wantedBy = [ "default.target" ];
    };
  };
}
