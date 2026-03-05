{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.opencode;

  wrapper = pkgs.symlinkJoin {
    name = "opencode";
    paths = [
      (pkgs.writeShellApplication {
        name = "opencode";
        runtimeInputs = [ cfg.package ];
        text = ''
          if [ $# -eq 0 ]; then
            ${optionalString (cfg.environmentFile != null) ''
              # shellcheck disable=SC1091
              . ${cfg.environmentFile}
            ''}
            export OPENCODE_SERVER_PASSWORD
            exec opencode attach --dir "$PWD" http://${cfg.hostname}:${toString cfg.port}
          else
            exec opencode "$@"
          fi
        '';
      })
      cfg.package
    ];
  };
in {
  options.services.opencode = {
    enable = mkEnableOption "opencode headless server";

    package = mkOption {
      type = types.package;
      default = pkgs.opencode;
      description = "The opencode package to use (also overrides programs.opencode.package)";
    };

    hostname = mkOption {
      type = types.str;
      default = "127.0.0.1";
      description = "Hostname for the opencode server";
    };

    port = mkOption {
      type = types.port;
      default = 16321;
      description = "Port for the opencode server";
    };

    environmentFile = mkOption {
      type = types.nullOr types.path;
      default = null;
      description = "Environment file containing secrets like server password";
    };

    path = mkOption {
      type = types.listOf types.package;
      default = [];
      description = "Extra packages to add to the server's PATH";
    };
  };

  config = mkIf cfg.enable {
    programs.opencode.package = wrapper;

    systemd.user.services.opencode = {
      Unit = {
        Description = "opencode headless server";
        After = [ "graphical-session.target" ];
        PartOf = [ "graphical-session.target" ];
        X-Restart-Triggers = [ config.xdg.configFile."opencode/config.json".source ];
      };

      Service = let
        execStart = "${lib.getExe cfg.package} serve --hostname ${cfg.hostname} --port ${toString cfg.port} --print-logs";
      in {
        Environment = [ "OPENCODE_EXPERIMENTAL_LSP_TOOL=true" ];
        ExecStart =
          if cfg.path == [] then execStart
          else "${pkgs.writeShellScript "opencode-serve" ''
            export PATH="${lib.makeBinPath cfg.path}:$PATH"
            exec ${execStart}
          ''}";
        EnvironmentFile = mkIf (cfg.environmentFile != null) cfg.environmentFile;
        Restart = "on-failure";
        RestartSteps = 5;
        RestartMaxDelaySec = 10;
      };

      Install = {
        WantedBy = [ "graphical-session.target" ];
      };
    };
  };
}
