{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.speaches;

  defaultEnvironment = {
    UVICORN_HOST = "0.0.0.0";
    ENABLE_UI = "false";
    DO_NOT_TRACK = "1";
    GRADIO_ANALYTICS_ENABLED = "false";
    DISABLE_TELEMETRY = "1";
    HF_HUB_DISABLE_TELEMETRY = "1";
    LOG_LEVEL = "info";
  };

  environment = defaultEnvironment // cfg.environment;

  envFlags = concatStringsSep " " (mapAttrsToList (k: v: "--env ${escapeShellArg "${k}=${v}"}") environment);

  execStart = pkgs.writeShellScript "speaches-start" ''
    mkdir -p ${cfg.modelCacheDir}
    exec ${pkgs.podman}/bin/podman run \
      --name speaches \
      --replace \
      --rm \
      --userns=keep-id \
      --cap-drop=ALL \
      --security-opt=no-new-privileges \
      --publish ${cfg.hostname}:${toString cfg.port}:8000 \
      --volume ${cfg.modelCacheDir}:/home/ubuntu/.cache/huggingface/hub:rw \
      --pull=missing \
      ${envFlags} \
      ${optionalString (cfg.environmentFile != null) "--env-file ${cfg.environmentFile}"} \
      ${cfg.image}
  '';
in {
  options.services.speaches = {
    enable = mkEnableOption "speaches speech processing server";

    image = mkOption {
      type = types.str;
      default = "ghcr.io/speaches-ai/speaches:latest-cpu";
      description = "OCI image to use for speaches";
    };

    hostname = mkOption {
      type = types.str;
      default = "127.0.0.1";
      description = "Address to bind to on host";
    };

    port = mkOption {
      type = types.port;
      default = 8000;
      description = "Port to expose on host";
    };

    modelCacheDir = mkOption {
      type = types.str;
      default = "${config.xdg.cacheHome}/speaches/models";
      description = "Directory to cache HuggingFace models";
    };

    environment = mkOption {
      type = types.attrsOf types.str;
      default = { };
      description = "Extra environment variables to pass to the container";
    };

    environmentFile = mkOption {
      type = types.nullOr types.path;
      default = null;
      description = "Environment file containing secrets like API_KEY";
    };
  };

  config = mkIf cfg.enable {
    home.packages = [ pkgs.speaches-cli ];

    systemd.user.services.speaches = {
      Unit = {
        Description = "speaches speech processing server";
        After = [ "default.target" ];
        PartOf = [ "default.target" ];
      };

      Service = {
        ExecStart = toString execStart;
        ExecStop = "${pkgs.podman}/bin/podman stop speaches";
        ExecStopPost = "${pkgs.podman}/bin/podman rm -f -i speaches";
        Type = "simple";
        Restart = "on-failure";
        RestartSteps = 5;
        RestartMaxDelaySec = 10;
      };

      Install = {
        WantedBy = [ "default.target" ];
      };
    };
  };
}
