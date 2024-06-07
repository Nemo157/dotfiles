{ name, config, ts, ... }: {
  services.grafana = {
    enable = true;
    settings.server.http_addr = ts.ips.${name};
    provision = {
      datasources.settings.datasources = [
        {
          name = "telegraf";
          type = "influxdb";
          url = "http://${name}.${ts.domain}:8086";
          jsonData = {
            dbName = "telegraf";
            timeInterval = "10s";
          };
        }
      ];
    };
  };
}
