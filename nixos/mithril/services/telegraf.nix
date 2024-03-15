{ ts, ... }: {
  services.telegraf = {
    enable = true;
    extraConfig = {
      inputs = {
        cpu = {};
      };
      outputs = {
        influxdb = {
          urls = [ "http://${ts.self.host}:8086" ];
        };
      };
    };
  };
}
