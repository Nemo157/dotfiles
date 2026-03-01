{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.f5-tts-server;

  defaultEnvironment = {
    DO_NOT_TRACK = "1";
  };

  environment = defaultEnvironment // cfg.environment;

  envFlags = concatStringsSep " " (mapAttrsToList (k: v: "--env ${escapeShellArg "${k}=${v}"}") environment);

  execStartPre = pkgs.writeShellScript "f5-tts-server-build" ''
    if ! ${pkgs.podman}/bin/podman image exists ${cfg.image}; then
      ${pkgs.podman}/bin/podman build \
        --build-arg GPU=rocm \
        -t ${cfg.image} \
        -f ${./f5-tts-server.Dockerfile} \
        $(mktemp -d)
    fi
  '';

  refAudiosDir = "${config.xdg.stateHome}/f5-tts-server/ref-audios";

  execStart = pkgs.writeShellScript "f5-tts-server-start" ''
    mkdir -p ${refAudiosDir}
    exec ${pkgs.podman}/bin/podman run \
      --name f5-tts-server \
      --replace \
      --rm \
      --cap-drop=ALL \
      --security-opt=no-new-privileges \
      --network=pasta:--no-map-gw \
      --publish ${cfg.hostname}:${toString cfg.port}:8000 \
      --device /dev/kfd \
      --device /dev/dri \
      --tmpfs /app/output:rw,mode=1777 \
      --volume ${refAudiosDir}:/app/ref_audios/custom:rw \
      ${envFlags} \
      ${optionalString (cfg.environmentFile != null) "--env-file ${cfg.environmentFile}"} \
      ${cfg.image}
  '';
in {
  options.services.f5-tts-server = {
    enable = mkEnableOption "F5-TTS-Server TTS server";

    image = mkOption {
      type = types.str;
      default = "localhost/f5-tts-server:latest";
      description = "OCI image to use for f5-tts-server";
    };

    hostname = mkOption {
      type = types.str;
      default = "127.0.0.1";
      description = "Address to bind to on host";
    };

    port = mkOption {
      type = types.port;
      default = 8005;
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
      description = "Environment file containing secrets like HF_TOKEN";
    };
  };

  config = mkIf cfg.enable {
    systemd.user.services.f5-tts-server = {
      Unit = {
        Description = "F5-TTS-Server TTS server";
        After = [ "default.target" ];
        PartOf = [ "default.target" ];
      };

      Service = {
        ExecStartPre = toString execStartPre;
        ExecStart = toString execStart;
        ExecStop = "${pkgs.podman}/bin/podman stop f5-tts-server";
        ExecStopPost = "${pkgs.podman}/bin/podman rm -f -i f5-tts-server";
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
