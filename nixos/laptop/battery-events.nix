{ lib, pkgs, ... }: let
  systemctl = lib.getExe' pkgs.systemd "systemctl";
in {
  systemd.targets = {
    ac = {
      description = "On AC power";
      unitConfig = {
        DefaultDependencies = false;
        BindsTo = [ "ac.device" ];
        After = [ "multi-user.target" ];
      };
      wantedBy = [ "ac.device" ];
    };
  };

  systemd.user.targets = {
    ac = {
      description = "On AC power";
      unitConfig = {
        DefaultDependencies = false;
        BindsTo = [ "ac.device" ];
        After = [ "default.target" ];
      };
      wantedBy = [ "ac.device" ];
    };
  };

  services.udev.extraRules = ''
    SUBSYSTEM=="power_supply", TAG+="systemd"
    SUBSYSTEM=="power_supply", ENV{SYSTEMD_ALIAS}="/ac"
    SUBSYSTEM=="power_supply", ATTR{online}=="0", ENV{SYSTEMD_READY}="0"
    SUBSYSTEM=="power_supply", ATTR{online}=="1", ENV{SYSTEMD_READY}="1"
  '';
}
