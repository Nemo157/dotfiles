{ lib, pkgs, config, ... }: {
  services.telegraf.extraConfig.inputs = {
    linux_cpu = {};
    sensors = {};
  };

  systemd.services.telegraf.path = [ pkgs.lm_sensors ];
}
