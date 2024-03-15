{ config, ts, ... }: {
  age.secrets.grafana-admin-password = {
    file = ./grafana-admin-password.age;
    owner = "grafana";
    group = "grafana";
  };

  services.grafana = {
    enable = true;
    settings = {
      server = {
        http_addr = ts.self.ip;
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
      datasources.settings.datasources = [
        {
          name = "telegraf";
          type = "influxdb";
          url = "http://${ts.self.host}:8086";
          jsonData = {
            dbName = "telegraf";
          };
        }
      ];
    };
  };
}
