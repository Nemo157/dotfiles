{ lib, pkgs, ... }: let
  systemctl = lib.getExe' pkgs.systemd "systemctl";
in {
  systemd.targets = {
    ac = {
      description = "On AC power";
      conflicts = [ "battery.target" ];
      unitConfig = {
        DefaultDependencies = false;
      };
    };

    battery = {
      description = "On battery power";
      conflicts = [ "ac.target" ];
      unitConfig = {
        DefaultDependencies = false;
      };
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
    "battery@" = {
      description = "On battery power (notify %I)";
      partOf = [ "battery.target" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = "${systemctl} --user --machine=%i@ start --wait battery.target";
      };
      wantedBy = [ "battery.target" ];
    };
    "battery@nemo157" = {
      overrideStrategy = "asDropin";
      wantedBy = [ "battery.target" ];
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

    battery = {
      description = "On battery power";
      conflicts = [ "ac.target" ];
      unitConfig = {
        DefaultDependencies = false;
      };
    };
  };

  services.udev.extraRules = ''
    SUBSYSTEM=="power_supply", ATTR{type}=="Mains", ATTR{online}=="0", RUN+="${systemctl} start battery.target"
    SUBSYSTEM=="power_supply", ATTR{type}=="Mains", ATTR{online}=="1", RUN+="${systemctl} start ac.target"
  '';
}
