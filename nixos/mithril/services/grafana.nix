{ name, config, ts, ... }: {
  services.grafana = {
    enable = true;
    settings = {
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

  services.caddy.virtualHosts."https://grafana.${ts.domain}" = {
    extraConfig = ''
      import tailscale "grafana"
      reverse_proxy ${config.services.grafana.settings.server.http_addr}:${toString config.services.grafana.settings.server.http_port}
    '';
  };
}
