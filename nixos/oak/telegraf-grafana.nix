{ config, ... }: {
  services.telegraf = {
    extraConfig = {
      outputs = {
        influxdb = {
          urls = [ "http://127.0.0.1:8086" ];
        };
      };
    };
  };

  services.influxdb = {
    enable = true;
    extraConfig = {
      http = {
        bind-address = "127.0.0.1:8086";
      };
    };
  };

  age.secrets.grafana-admin-password = {
    file = ./grafana-admin-password.age;
    owner = "grafana";
    group = "grafana";
  };

  services.grafana = {
    enable = true;
    settings = {
      server = {
        http_addr = "127.0.0.1";
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
          url = "http://127.0.0.1:8086";
          jsonData = {
            dbName = "telegraf";
            timeInterval = "10s";
          };
        }
      ];
    };
  };
}
