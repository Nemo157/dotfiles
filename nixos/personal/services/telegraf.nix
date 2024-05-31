{ ts, ... }: {
  services.telegraf = {
    extraConfig = {
      outputs = {
        influxdb = {
          urls = [ "http://${ts.hosts.mithril.host}:8086" ];
        };
      };
    };
  };
}
