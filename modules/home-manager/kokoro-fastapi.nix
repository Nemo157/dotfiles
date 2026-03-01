{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.kokoro-fastapi;

  defaultEnvironment = {
    UVICORN_HOST = "0.0.0.0";
    DO_NOT_TRACK = "1";
    DISABLE_TELEMETRY = "1";
  };

  environment = defaultEnvironment // cfg.environment;

  envFlags = concatStringsSep " " (mapAttrsToList (k: v: "--env ${escapeShellArg "${k}=${v}"}") environment);

  execStart = pkgs.writeShellScript "kokoro-fastapi-start" ''
    exec ${pkgs.podman}/bin/podman run \
      --name kokoro-fastapi \
      --replace \
      --rm \
      --userns=keep-id \
      --cap-drop=ALL \
      --security-opt=no-new-privileges \
      --network=pasta:--no-map-gw \
      --publish ${cfg.hostname}:${toString cfg.port}:8880 \
      --pull=missing \
      ${envFlags} \
      ${optionalString (cfg.environmentFile != null) "--env-file ${cfg.environmentFile}"} \
      ${cfg.image}
  '';
in {
  options.services.kokoro-fastapi = {
    enable = mkEnableOption "kokoro-fastapi TTS server";

    image = mkOption {
      type = types.str;
      default = "ghcr.io/remsky/kokoro-fastapi-cpu:latest";
      description = "OCI image to use for kokoro-fastapi";
    };

    hostname = mkOption {
      type = types.str;
      default = "127.0.0.1";
      description = "Address to bind to on host";
    };

    port = mkOption {
      type = types.port;
      default = 8880;
      description = "Port to expose on host";
    };

    environment = mkOption {
      type = types.attrsOf types.str;
      default = { };
      description = "Extra environment variables to pass to the container";
    };

    environmentFile = mkOption {
      type = types.nullOr types.path;
      default = null;
      description = "Environment file containing secrets";
    };
  };

  config = mkIf cfg.enable {
    systemd.user.services.kokoro-fastapi = {
      Unit = {
        Description = "kokoro-fastapi TTS server";
        After = [ "default.target" ];
        PartOf = [ "default.target" ];
      };

      Service = {
        ExecStart = toString execStart;
        ExecStop = "${pkgs.podman}/bin/podman stop kokoro-fastapi";
        ExecStopPost = "${pkgs.podman}/bin/podman rm -f -i kokoro-fastapi";
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
