{ name, config, ts, ... }: {
  age.secrets.grafana-admin-password = {
    file = ./admin-password.age;
    owner = "grafana";
    group = "grafana";
  };

  services.grafana = {
    enable = true;
    settings = {
      server = {
        http_addr = ts.ips.${name};
        http_port = 3001;
      };
      analytics = {
        reporting_enabled = false;
        feedback_links_enabled = false;
      };
      security = {
        admin_password = "$__file{${config.age.secrets.grafana-admin-password.path}}";
      };
    };
    provision = {
      enable = true;
      dashboards.settings.providers = [
        {
          disableDeletion = true;
          updateIntervalSeconds = 31536000;
          allowUiUpdates = false;
          options = {
            path = ./dashboards;
            foldersFromFilesStructure = true;
          };
        }
      ];
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
