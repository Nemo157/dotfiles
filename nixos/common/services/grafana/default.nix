{ name, config, ts, lib, ... }: {
  age.secrets.grafana-admin-password = lib.mkIf config.services.grafana.enable {
    file = ./admin-password.age;
    owner = "grafana";
    group = "grafana";
  };

  services.grafana = {
    settings = {
      server = {
        http_addr = lib.mkDefault "127.0.0.1";
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
      datasources.settings.datasources = lib.mkDefault [
        {
          name = "telegraf";
          type = "influxdb";
          url = "http://localhost:8086";
          jsonData = {
            dbName = "telegraf";
            timeInterval = "10s";
          };
        }
      ];
    };
  };
}
