{ config, ... }: {
  services.telegraf = {
    extraConfig = {
      inputs = {
        docker = {};
        linux_cpu = {};
        sensors = {};
      };
      outputs = {
        influxdb = {
          urls = [ "http://127.0.0.1:8086" ];
        };
      };
    };
  };

  users.users.telegraf.extraGroups = [ "docker" ];

  services.influxdb = {
    enable = true;
    extraConfig = {
      http = {
        bind-address = "127.0.0.1:8086";
      };
    };
  };

  services.grafana = {
    enable = true;
  };
}
