{ lib, pkgs, config, ... }: {
  services.telegraf.extraConfig.inputs = {
    docker = {};
    linux_cpu = {};
    amd_rocm_smi = {
      bin_path = lib.getExe' pkgs.rocmPackages.rocm-smi "rocm-smi";
    };
    sensors = {};
    zfs = {
      poolMetrics = true;
      datasetMetrics = true;
    };
  };

  users.users.telegraf.extraGroups = [ "docker" ];
}
