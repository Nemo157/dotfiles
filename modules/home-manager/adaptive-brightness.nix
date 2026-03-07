{ config, lib, pkgs, ... }:
let
  cfg = config.services.adaptive-brightness;

  script = pkgs.writers.writePython3Bin "adaptive-brightness" { } (builtins.readFile ./adaptive-brightness.py);
in {
  options.services.adaptive-brightness = {
    enable = lib.mkEnableOption "adaptive monitor brightness based on ambient light";

    ha_url = lib.mkOption {
      type = lib.types.str;
      description = "Home Assistant base URL";
    };

    tokenFile = lib.mkOption {
      type = lib.types.path;
      description = "Path to file containing the Home Assistant long-lived access token";
    };

    sensorEntityId = lib.mkOption {
      type = lib.types.str;
      description = "Home Assistant entity ID for the illuminance sensor";
    };

    luxMin = lib.mkOption {
      type = lib.types.int;
      default = 5;
      description = "Minimum lux value for mapping";
    };

    luxMax = lib.mkOption {
      type = lib.types.int;
      default = 10000;
      description = "Maximum lux value for mapping";
    };

    brightnessMin = lib.mkOption {
      type = lib.types.int;
      default = 15;
      description = "Minimum brightness percentage";
    };

    brightnessMax = lib.mkOption {
      type = lib.types.int;
      default = 100;
      description = "Maximum brightness percentage";
    };

    interval = lib.mkOption {
      type = lib.types.int;
      default = 30;
      description = "Polling interval in seconds";
    };

    hysteresis = lib.mkOption {
      type = lib.types.int;
      default = 2;
      description = "Minimum brightness change to trigger update";
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.user.services.adaptive-brightness = {
      Unit = {
        Description = "Adaptive monitor brightness based on ambient light";
        After = [ "default.target" ];
        PartOf = [ "default.target" ];
      };

      Service = {
        ExecStart = "${lib.getExe script}";
        Type = "simple";
        Restart = "on-failure";
        RestartSec = 10;
        Environment = [
          "HA_URL=${cfg.ha_url}"
          "TOKEN_FILE=%d/ha-token"
          "SENSOR_ENTITY_ID=${cfg.sensorEntityId}"
          "LUX_MIN=${toString cfg.luxMin}"
          "LUX_MAX=${toString cfg.luxMax}"
          "BRIGHTNESS_MIN=${toString cfg.brightnessMin}"
          "BRIGHTNESS_MAX=${toString cfg.brightnessMax}"
          "INTERVAL=${toString cfg.interval}"
          "HYSTERESIS=${toString cfg.hysteresis}"
          "PATH=${lib.makeBinPath [ pkgs.ddcutil pkgs.coreutils ]}"
        ];
        LoadCredential = "ha-token:${cfg.tokenFile}";
      };

      Install = {
        WantedBy = [ "default.target" ];
      };
    };
  };
}
