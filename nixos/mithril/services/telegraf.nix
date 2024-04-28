{ lib, pkgs, config, ... }: {
  services.telegraf.extraConfig.inputs = {
    docker = {};
    nvidia_smi = {
      bin_path = lib.getExe' config.hardware.nvidia.package "nvidia-smi";
    };
    zfs = {
      poolMetrics = true;
      datasetMetrics = true;
    };
  };

  users.users.telegraf.extraGroups = [ "docker" ];
}
