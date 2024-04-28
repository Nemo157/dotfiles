{ lib, pkgs, config, ... }: {
  services.telegraf.extraConfig.inputs = {
    docker = {};
    linux_cpu = {};
    nvidia_smi = {
      bin_path = lib.getExe' config.hardware.nvidia.package "nvidia-smi";
    };
    sensors = {};
    zfs = {
      poolMetrics = true;
      datasetMetrics = true;
    };
  };

  users.users.telegraf.extraGroups = [ "docker" ];
}
