{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.chatterbox-tts;

  defaultEnvironment = {
    DO_NOT_TRACK = "1";
    NUMBA_CACHE_DIR = "/tmp/numba_cache";
  };

  environment = defaultEnvironment // cfg.environment;

  envFlags = concatStringsSep " " (mapAttrsToList (k: v: "--env ${escapeShellArg "${k}=${v}"}") environment);

  configFile = (pkgs.formats.yaml { }).generate "chatterbox-tts-config.yaml" {
    device = "auto";
    host = "0.0.0.0";
  };

  execStart = pkgs.writeShellScript "chatterbox-tts-start" ''
    mkdir -p ${cfg.modelCacheDir}
    exec ${pkgs.podman}/bin/podman run \
      --name chatterbox-tts \
      --replace \
      --rm \
      --userns=keep-id \
      --cap-drop=ALL \
      --security-opt=no-new-privileges \
      --publish ${cfg.hostname}:${toString cfg.port}:8000 \
      --volume ${cfg.modelCacheDir}:/app/hf_cache:rw \
      --tmpfs /app/logs:rw,mode=1777 \
      --volume ${configFile}:/app/config.yaml:ro \
      --pull=missing \
      ${envFlags} \
      ${optionalString (cfg.environmentFile != null) "--env-file ${cfg.environmentFile}"} \
      ${cfg.image}
  '';
in {
  options.services.chatterbox-tts = {
    enable = mkEnableOption "chatterbox-tts TTS server";

    image = mkOption {
      type = types.str;
      default = "ghcr.io/devnen/chatterbox-tts-server:main";
      description = "OCI image to use for chatterbox-tts";
    };

    hostname = mkOption {
      type = types.str;
      default = "127.0.0.1";
      description = "Address to bind to on host";
    };

    port = mkOption {
      type = types.port;
      default = 8004;
      description = "Port to expose on host";
    };

    modelCacheDir = mkOption {
      type = types.str;
      default = "${config.xdg.cacheHome}/chatterbox-tts/models";
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
      description = "Environment file containing secrets like HF_TOKEN";
    };
  };

  config = mkIf cfg.enable {
    systemd.user.services.chatterbox-tts = {
      Unit = {
        Description = "chatterbox-tts TTS server";
        After = [ "default.target" ];
        PartOf = [ "default.target" ];
      };

      Service = {
        ExecStart = toString execStart;
        ExecStop = "${pkgs.podman}/bin/podman stop chatterbox-tts";
        ExecStopPost = "${pkgs.podman}/bin/podman rm -f -i chatterbox-tts";
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
