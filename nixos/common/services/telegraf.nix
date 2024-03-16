{ pkgs, ts, ... }: {
  services.telegraf = {
    enable = true;
    extraConfig = {
      inputs = {
        cpu = {};
        disk = {};
        diskio = {};
        linux_cpu = {};
        mem = {};
        net = {
          ignore_protocol_stats = true;
        };
        netstat = {};
        processes = {};
        sensors = {};
        swap = {};
        temp = {};
      };
      outputs = {
        influxdb = {
          urls = [ "http://${ts.mithril.host}:8086" ];
        };
      };
    };
  };

  systemd.services.telegraf.path = [ pkgs.lm_sensors ];
}
