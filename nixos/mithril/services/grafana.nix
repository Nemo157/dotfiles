{ name, config, ts, ... }: {
  services.grafana = {
    enable = true;
    settings = {
      server.http_addr = ts.ips.${name};
      analytics = {
        enabled = false;
        reporting_enabled = false;
        check_for_updates = false;
        check_for_plugin_updates = false;
        feedback_links_enabled = false;
      };
    };
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
