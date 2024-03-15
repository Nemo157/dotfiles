{ lib, pkgs, ts, config, ... }: {
  services.telegraf = {
    enable = true;
    extraConfig = {
      inputs = {
        cpu = {};
        docker = {};
        linux_cpu = {};
        mem = {};
        net = {
          ignore_protocol_stats = true;
        };
        netstat = {};
        nvidia_smi = {
          bin_path = lib.getExe' config.hardware.nvidia.package "nvidia-smi";
        };
        processes = {};
        sensors = {};
        swap = {};
        temp = {};
        zfs = {
          poolMetrics = true;
          datasetMetrics = true;
        };
      };
      outputs = {
        influxdb = {
          urls = [ "http://${ts.self.host}:8086" ];
        };
      };
    };
  };

  users.users.telegraf.extraGroups = [ "docker" ];

  systemd.services.telegraf.path = [ pkgs.lm_sensors ];
}
